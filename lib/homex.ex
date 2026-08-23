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
         node_id: config.node_id,
         devices: config.devices,
         origin: config.origin
       ]},
      {DynamicSupervisor, name: Homex.EntitySupervisor, strategy: :one_for_one},
      {Registry, name: Homex.Subscribers, keys: :duplicate},
      {DynamicSupervisor, name: Homex.AdapterSupervisor, strategy: :one_for_one},
      {Task,
       fn ->
         if config.adapters == [] do
           Logger.warning("no adapters configured, entities run but are not published anywhere")
         end

         Homex.add_adapters(config.adapters)
         Homex.add_entities(config.entities)
       end}
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end

  @moduledoc """

  ## Configuration

  `Homex` takes its configuration as start options in your supervision tree —
  there is no global state and no application environment involved:

  ```elixir
  {Homex,
   node_id: Homex.hostname(),
   adapters: [{Homex.Adapter.MQTT, broker: [host: "localhost", port: 1883]}],
   entities: [MyEntity]}
  ```

  The available options are documented in `Homex.Config`. Each adapter documents
  its own options — see `Homex.Adapter.MQTT`.

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

  Add `homex` to your supervision tree with your entities and the adapters that
  publish them — without an adapter the entities still run, they are just not
  published anywhere. Entities can also be added/removed at runtime with
  `Homex.add_entity/1` or `Homex.remove_entity/1`.

  ```elixir
  defmodule MyApp.Application do
    def start(_type, _args) do
      children =
        [
          ...,
          {Homex,
           node_id: Homex.hostname(),
           adapters: [{Homex.Adapter.MQTT, broker: [host: "localhost", port: 1883]}],
           entities: [MySwitch]},
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

  defp meta(key, default) do
    case Registry.meta(Homex.EntityRegistry, key) do
      {:ok, value} -> value
      :error -> default
    end
  end

  def node_id() do
    case meta(:node_id, nil) do
      nil -> raise "node id must be set"
      id -> id
    end
  end

  @doc false
  def devices(), do: meta(:devices, %{})

  @doc false
  def origin(), do: meta(:origin, %{})

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

  def subscribe, do: Registry.register(Homex.Subscribers, :entities, nil)

  def broadcast(msg) do
    Registry.dispatch(Homex.Subscribers, :entities, fn subscribers ->
      for {pid, _} <- subscribers, do: send(pid, msg)
    end)
  end

  defp notify_subscribers(), do: Homex.broadcast({:homex, :entities_changed})

  def add_entity(opts) do
    with :ok <- start_entity(opts) do
      notify_subscribers()
    end
  end

  def add_entities(entities) do
    Enum.each(entities, &start_entity/1)
    notify_subscribers()
  end

  def add_adapter(opts) do
    start_adapter(opts)
  end

  def add_adapters(adapters) do
    Enum.each(adapters, &start_adapter/1)
  end

  @doc """
  Adds the device or replaces the one already registered under `id`.

  See `Homex.Device` for the available options.
  """
  # TODO: read-modify-write on the registry meta, concurrent callers can lose an
  # update. Serialize through a process if devices ever get written from more
  # than one place.
  @spec put_device(Homex.Device.id(), keyword()) ::
          :ok | {:error, NimbleOptions.ValidationError.t()}
  def put_device(id, opts \\ []) do
    with {:ok, device} <- Homex.Device.new(id, opts) do
      Registry.put_meta(Homex.EntityRegistry, :devices, Map.put(devices(), id, device))
      notify_subscribers()
    end
  end

  @doc """
  Removes the device registered under `id`.

  Entities on that device keep running but are no longer published, until a
  device is registered under the same id again.
  """
  @spec delete_device(Homex.Device.id()) :: :ok
  def delete_device(id) do
    Registry.put_meta(Homex.EntityRegistry, :devices, Map.delete(devices(), id))
    notify_subscribers()
  end

  defp start_entity(spec) do
    with {:ok, entity} <- Homex.Entity.new(spec),
         {:ok, _pid} <-
           DynamicSupervisor.start_child(Homex.EntitySupervisor, {Homex.Entity, entity}) do
      :ok
    end
  end

  def remove_entity(name) do
    case Registry.lookup(Homex.EntityRegistry, name) do
      [{pid, _descriptor}] ->
        :ok = GenServer.call(pid, {:homex, :remove})
        notify_subscribers()

      [] ->
        {:error, :not_found}
    end
  end

  def start_adapter(spec), do: DynamicSupervisor.start_child(Homex.AdapterSupervisor, spec)

  @doc "The running adapters as `{module, pid}` pairs"
  def adapters do
    for {_, pid, _, [module]} <- DynamicSupervisor.which_children(Homex.AdapterSupervisor),
        do: {module, pid}
  end

  def remove_adapter(pid) when is_pid(pid),
    do: DynamicSupervisor.terminate_child(Homex.AdapterSupervisor, pid)

  def remove_adapter(module) when is_atom(module) do
    case List.keyfind(adapters(), module, 0) do
      {^module, pid} -> remove_adapter(pid)
      nil -> {:error, :not_found}
    end
  end

  @doc false
  def hostname do
    case :inet.gethostname() do
      {:ok, hostname} -> to_string(hostname)
      _ -> "homex"
    end
  end
end
