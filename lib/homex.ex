defmodule Homex do
  use Supervisor

  def start_link(init_arg \\ []) do
    {name, rest} = Keyword.pop(init_arg, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, rest, name: name)
  end

  @impl Supervisor
  def init(_opts \\ []) do
    config = Homex.Config.get()

    children = [
      {DynamicSupervisor, name: Homex.EntitySupervisor, strategy: :one_for_one},
      {Homex.Manager, config},
      {Registry, name: Homex.SubscriptionRegistry, keys: :duplicate, listeners: [Homex.Manager]},
      {Task, fn -> Homex.add_entities(config.entities) end}
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end

  @moduledoc """

  ## Configuration

  You can configure `Homex` through a normal config entry like

  ```elixir
  import Config

  config :homex,
    broker: [host: "localhost", port: 1883],
    entities: [MyEntity]
  ```

  The available options are documented in `Homex.Config`.


  ## Usage

  Define a module for the type of entity you want to use. The available types are:

  - `Homex.Entity.Switch`
  - `Homex.Entity.Sensor`
  - `Homex.Entity.Light`

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

  Configure broker and entities. Entities can also be added/removed at runtime with `Homex.add_entity/1` or `Homex.remove_entity/1`.

  ```elixir
  import Config

  config :homex,
    entities: [MySwitch]
  ```

  Add `homex` to you supervision tree

  ```elixir
  defmodule MyApp.Application do
    def start(_type, _args) do
      children =
        [
          ...,
          Homex,
          ...
        ]

      opts = [strategy: :one_for_one, name: MyApp.Supervisor]
      Supervisor.start_link(children, opts)
    end
  end
  ```
  """

  defdelegate connected?(), to: Homex.Manager
  defdelegate publish(topic, payload, opts), to: Homex.Manager
  defdelegate entities(), to: Homex.Manager
  defdelegate entity(name_or_module), to: Homex.Manager
  defdelegate add_entity(module), to: Homex.Manager
  defdelegate add_entities(modules), to: Homex.Manager
  defdelegate remove_entity(module), to: Homex.Manager

  @doc false
  def hostname do
    case :inet.gethostname() do
      {:ok, hostname} -> to_string(hostname)
      _ -> "homex"
    end
  end

  @doc false
  @spec unique_id(String.t(), [term()]) :: String.t()
  def unique_id(name, identifiers) do
    escaped = escape(name)
    "#{escaped}_#{:erlang.phash2([escaped | identifiers])}"
  end

  @doc false
  @spec escape(String.t()) :: String.t()
  def escape(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end
end
