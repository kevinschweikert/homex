defmodule Homex do
  use Supervisor

  require Logger

  def start_link(init_arg \\ []) do
    {name, rest} = Keyword.pop(init_arg, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, rest, name: name)
  end

  @impl Supervisor
  def init(opts \\ []) do
    config = Homex.Config.new(opts)

    # TODO: how can we make the process names dynamic, so the user can control the naming and start multiple instances of homex
    # Module.concat/2?
    # how do we pass through the root name?
    # How does e.g. Homex.notify know the root name -> Homex.notify(MyHomex, "my-entity", msg)
    # persistent_term?
    children = [
      {Registry,
       name: Homex.EntityRegistry,
       keys: :unique,
       meta: [
         device: config.device,
         adapters: [{Homex.Adapter.MQTT, Homex.Adapter.MQTT}]
       ]},
      {DynamicSupervisor, name: Homex.EntitySupervisor, strategy: :one_for_one},
      {Task, fn -> Homex.add_entities(config.entities) end},
      # TODO: start conditionally!
      {Homex.Adapter.MQTT, config}
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end

  @moduledoc """

  ## Configuration

  `Homex` takes its configuration as start options in your supervision tree —
  there is no global state and no application environment involved:

  ```elixir
  {Homex, broker: [host: "localhost", port: 1883], entities: [MyEntity]}
  ```

  The available options are documented in `Homex.Config`.

  ## Usage

  Define a module for the type of entity you want to use. The available types are:

  - `Homex.Entity.Switch`
  - `Homex.Entity.Sensor`
  - `Homex.Entity.Light`
  - `Homex.Entity.Button`
  - `Homex.Entity.DeviceTrigger`
  - `Homex.Entity.Camera`


  ```elixir
  defmodule MySwitch do
    use Homex.Entity.Switch, name: "my-switch"

    def handle_on(state) do
      IO.puts("Switch turned on")
      {:noreply, state}
    end

    def handle_off(state) do
      IO.puts("Switch turned off")
      {:noreply, state}
    end
  end
  ```

  Add `homex` to your supervision tree with your entities. Entities can also be
  added/removed at runtime with `Homex.add_entity/1` or `Homex.remove_entity/1`.

  ```elixir
  defmodule MyApp.Application do
    def start(_type, _args) do
      children =
        [
          ...,
          {Homex, entities: [MySwitch]},
          ...
        ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ```
  """

  @json_library if(Code.ensure_loaded?(JSON), do: JSON, else: Jason)

  def encode!(encodable), do: @json_library.encode!(encodable)
  def decode!(decodable), do: @json_library.decode!(decodable)
  def decode(decodable), do: @json_library.decode(decodable)

  @doc "The running adapter instances as `{module, instance}` pairs"
  def adapters() do
    case Registry.meta(Homex.EntityRegistry, :adapters) do
      {:ok, adapters} -> adapters
      :error -> []
    end
  end

  @doc false
  def device() do
    case Registry.meta(Homex.EntityRegistry, :device) do
      {:ok, device} -> device
      :error -> %{}
    end
  end

  def descriptor(name) do
    case Registry.lookup(Homex.EntityRegistry, name) do
      [{_pid, descriptor}] -> {:ok, descriptor}
      _ -> {:error, :not_found}
    end
  end

  @doc "The descriptors of all running entities"
  def descriptors do
    Registry.select(Homex.EntityRegistry, [{{:_, :_, :"$3"}, [], [:"$3"]}])
  end

  @doc "send a message to the entity"
  def notify(name, msg) do
    case Registry.lookup(Homex.EntityRegistry, name) do
      [{pid, _value}] ->
        send(pid, msg)
        :ok

      _ ->
        {:error, :not_found}
    end
  end

  def cast(name, msg) do
    case Registry.lookup(Homex.EntityRegistry, name) do
      [{pid, _value}] -> GenServer.cast(pid, msg)
      _ -> {:error, :not_found}
    end
  end

  def call(name, msg) do
    case Registry.lookup(Homex.EntityRegistry, name) do
      [{pid, _value}] -> GenServer.call(pid, msg)
      _ -> {:error, :not_found}
    end
  end

  def add_entity(opts) do
    with :ok <- start_entity(opts) do
      notify_adapters()
    end
  end

  def add_entities(entities) do
    Enum.each(entities, &start_entity/1)
    notify_adapters()
  end

  defp start_entity(opts) do
    with %Homex.Entity{} = entity <- Homex.Entity.new(opts),
         {:ok, _pid} <-
           DynamicSupervisor.start_child(Homex.EntitySupervisor, {Homex.Entity, entity}) do
      :ok
    else
      nil ->
        Logger.error("Can't add entity, invalid configuration #{inspect(opts)}")
        {:error, :entity_invalid}

      {:error, reason} ->
        Logger.error("Can't start entity #{inspect(opts)}: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def remove_entity(name) do
    case Registry.lookup(Homex.EntityRegistry, name) do
      [{pid, _descriptor}] ->
        :ok = GenServer.call(pid, {:homex, :remove})
        notify_adapters()

      [] ->
        {:error, :not_found}
    end
  end

  defp notify_adapters() do
    for {module, instance} <- adapters() do
      module.entities_changed(instance)
    end

    :ok
  end

  @doc false
  def hostname do
    case :inet.gethostname() do
      {:ok, hostname} -> to_string(hostname)
      _ -> "homex"
    end
  end

  def slug(binary) when is_binary(binary) do
    binary
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
