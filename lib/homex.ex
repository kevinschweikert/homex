defmodule Homex do
  use Supervisor

  def start_link(init_arg \\ []) do
    {name, rest} = Keyword.pop(init_arg, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, rest, name: name)
  end

  @impl Supervisor
  def init(_opts \\ []) do
    config = config()

    children = [
      {DynamicSupervisor, name: Homex.EntitySupervisor, strategy: :one_for_one},
      {Homex.Manager, config},
      {Registry, name: Homex.SubscriptionRegistry, keys: :duplicate, listeners: [Homex.Manager]},
      {Task, fn -> Homex.add_entities(config.entities) end}
    ]

    opts = [strategy: :rest_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end

  @config_schema [
                   device: [
                     default: [],
                     required: false,
                     type: :keyword_list,
                     doc:
                       "If no device configuration is given the identifiers and name will be set to the hostname of the device running Homex and will fall back to \"homex device\" when hostname is not available",
                     keys: [
                       identifiers: [required: false, type: {:or, [{:list, :string}, :mfa]}],
                       name: [required: false, type: {:or, [:string, :mfa]}],
                       manufacturer: [required: false, type: {:or, [:string, :mfa]}],
                       model: [required: false, type: {:or, [:string, :mfa]}],
                       serial_number: [required: false, type: {:or, [:string, :mfa]}],
                       sw_version: [required: false, type: {:or, [:string, :mfa]}],
                       hw_version: [required: false, type: {:or, [:string, :mfa]}]
                     ]
                   ],
                   origin: [
                     required: false,
                     type: :non_empty_keyword_list,
                     default: [name: "homex"],
                     keys: [
                       name: [
                         required: false,
                         type: :string,
                         default: "homex",
                         doc:
                           "The name of the application that is the origin of the discovered MQTT item."
                       ],
                       sw_version: [
                         required: false,
                         type: :string,
                         doc:
                           "Software version of the application that supplies the discovered MQTT item"
                       ],
                       support_url: [
                         required: false,
                         type: :string,
                         doc:
                           "Support URL of the application that supplies the discovered MQTT item"
                       ]
                     ]
                   ],
                   discovery_prefix: [
                     required: false,
                     type: :string,
                     default: "homeassistant",
                     doc:
                       "if changed in Homeassistant you also need to change it here to enable autodiscovery. The default works for a standard installation"
                   ],
                   entities: [required: false, default: [], type: {:list, :atom}],
                   broker: [
                     required: false,
                     default: [],
                     type: :keyword_list,
                     keys: [
                       host: [type: :string, default: "localhost", doc: "host of the MQTT broker"],
                       port: [type: :integer, default: 1883, doc: "port of the MQTT broker"],
                       username: [
                         type: :string,
                         doc: "username for the MQTT broker"
                       ],
                       password: [
                         type: :string,
                         doc: "passwort for the MQTT broker"
                       ]
                     ]
                   ]
                 ]
                 |> NimbleOptions.new!()

  @moduledoc """

  ## Configuration

  You can configure `Homex` through a normal config entry like

  ```elixir
  import Config

  config :homex,
    broker: [host: "localhost", port: 1883],
    entities: [MyEntity]
  ```

  The available options are:

  #{NimbleOptions.docs(@config_schema)}

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
  defdelegate add_entity(module), to: Homex.Manager
  defdelegate add_entities(modules), to: Homex.Manager
  defdelegate remove_entity(module), to: Homex.Manager

  @doc false
  def config_schema(), do: @config_schema

  @doc false
  def config, do: Application.get_all_env(:homex) |> Homex.Config.new()

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
