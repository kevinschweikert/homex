defmodule Homex do
  @config_schema [
                   device: [
                     default: [],
                     required: false,
                     type: :non_empty_keyword_list,
                     doc:
                       "If no device configuration is given the identifiers and name will be set to the hostname of the device running Homex and will fall back to \"homex device\" when hostname is not available",
                     keys: [
                       identifiers: [required: true, type: {:list, :string}],
                       name: [required: false, type: :string],
                       manufacturer: [required: false, type: :string],
                       model: [required: false, type: :string],
                       serial_number: [required: false, type: :string],
                       sw_version: [required: false, type: :string],
                       hw_version: [required: false, type: :string]
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
                   qos: [required: false, type: :integer, default: 1],
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
                         default: "admin",
                         doc: "username for the MQTT broker"
                       ],
                       password: [
                         type: :string,
                         default: "admin",
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

  defdelegate start_link(opts \\ []), to: Homex.Supervisor
  defdelegate publish(topic, payload, opts), to: Homex.Manager
  defdelegate add_entity(module), to: Homex.Manager
  defdelegate remove_entity(module), to: Homex.Manager

  @doc """
  Generates a unique ID from the platform name and entity name

  ## Example

      iex> Homex.unique_id("switch", "my-entity")
      "switch_my_entity_91165224"
  """
  @spec unique_id(String.t(), String.t()) :: String.t()
  def unique_id(platform, name) do
    "#{platform}_#{entity_id(name)}_#{:erlang.phash2({platform, name})}"
  end

  @doc """
  Generates an escaped string from the entity name

  ## Example

      iex> Homex.entity_id("my-entity!?")
      "my_entity"

      iex> Homex.entity_id("--my-entity--")
      "my_entity"

      iex> Homex.entity_id("my         entity")
      "my_entity"

      iex> Homex.entity_id("_my entity_")
      "my_entity"
  """
  @spec entity_id(String.t()) :: String.t()
  def entity_id(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  @doc """
  Returns the statically defined entities from the config
  """
  @spec entities() :: [atom()]
  def entities do
    user_config_with_defaults()
    |> NimbleOptions.validate!(@config_schema)
    |> Keyword.get(:entities)
  end

  @doc """
  Returns the Home Assistant discovery prefix
  """
  @spec discovery_prefix() :: String.t()
  def discovery_prefix do
    user_config_with_defaults()
    |> NimbleOptions.validate!(@config_schema)
    |> Keyword.get(:discovery_prefix)
  end

  @doc """
  Returns the Home Assistant discovery config. This is a Map/JSON payload which contains all the necessary device and component data.data.
  See https://www.home-assistant.io/integrations/mqtt/#mqtt-discovery for more information
  """
  @spec discovery_config() :: map()
  def discovery_config(components \\ %{}) do
    config =
      user_config_with_defaults()
      |> NimbleOptions.validate!(@config_schema)

    %{
      device: Enum.into(config[:device], %{}),
      origin: Enum.into(config[:origin], %{}),
      components: components,
      qos: config[:qos]
    }
  end

  @doc """
  Returns the broker config for EMQTT, the MQTT client used in this library
  """
  @spec emqtt_options() :: Keyword.t()
  def emqtt_options do
    config =
      user_config_with_defaults()
      |> NimbleOptions.validate!(@config_schema)

    [
      reconnect: :infinity,
      host: String.to_charlist(config[:broker][:host]),
      port: config[:broker][:port],
      username: String.to_charlist(config[:broker][:username]),
      password: String.to_charlist(config[:broker][:password])
    ]
  end

  defp user_config_with_defaults do
    hostname =
      case :inet.gethostname() do
        {:ok, hostname} -> to_string(hostname)
        {:error, _} -> "homex device"
      end

    Application.get_all_env(:homex)
    |> Keyword.merge(device: [identifiers: [hostname], name: hostname])
  end
end
