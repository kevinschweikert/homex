defmodule Homex do
  @config_schema [
                   device: [
                     default: [],
                     required: false,
                     type: :non_empty_keyword_list,
                     doc:
                       "If no device configuration is given the identifiers will be set to the hostname of the device running Homex and will fall back to 'homex device' when hostname is not available",
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
                   discovery_prefix: [required: false, type: :string, default: "homeassistant"],
                   qos: [required: false, type: :integer, default: 1],
                   entities: [required: false, default: [], type: {:list, :atom}],
                   emqtt: [
                     required: false,
                     type: :non_empty_keyword_list,
                     default: [
                       reconnect: :infinity,
                       host: "localhost",
                       port: 1883,
                       username: "admin",
                       password: "admin"
                     ],
                     keys: [
                       reconnect: [type: {:or, [:atom, :integer]}, default: :infinity],
                       host: [type: :string, default: "localhost"],
                       port: [type: :integer, default: 1883],
                       username: [type: :string, default: "admin"],
                       password: [type: :string, default: "admin"]
                     ]
                   ]
                 ]
                 |> NimbleOptions.new!()

  @moduledoc """

  Documentation for `Homex`.

  #{NimbleOptions.docs(@config_schema)}
  """

  defdelegate start_link(opts \\ []), to: Homex.Supervisor
  defdelegate publish(topic, payload), to: Homex.Manager
  defdelegate subscribe(topic), to: Homex.Manager
  defdelegate unsubscribe(topic), to: Homex.Manager
  defdelegate add_entity(module), to: Homex.Manager
  defdelegate remove_entity(module), to: Homex.Manager

  def unique_id(name) do
    "#{entity_id(name)}_#{:erlang.phash2(name)}"
  end

  def entity_id(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]/, "_")
  end

  def entities do
    Application.get_all_env(:homex)
    |> NimbleOptions.validate!(@config_schema)
    |> Keyword.get(:entities)
  end

  def discovery_prefix do
    Application.get_all_env(:homex)
    |> NimbleOptions.validate!(@config_schema)
    |> Keyword.get(:discovery_prefix)
  end

  def discovery_config(components \\ %{}) do
    hostname =
      case :inet.gethostname() do
        {:ok, hostname} -> to_string(hostname)
        {:error, _} -> "homex device"
      end

    config =
      Application.get_all_env(:homex)
      |> Keyword.merge(device: [identifiers: [hostname], name: hostname])
      |> NimbleOptions.validate!(@config_schema)

    %{
      device: Enum.into(config[:device], %{}),
      origin: Enum.into(config[:origin], %{}),
      components: components,
      qos: config[:qos]
    }
  end

  def emqtt_options do
    config =
      Application.get_all_env(:homex)
      |> NimbleOptions.validate!(@config_schema)

    [
      reconnect: config[:emqtt][:reconnect],
      host: String.to_charlist(config[:emqtt][:host]),
      port: config[:emqtt][:port],
      username: String.to_charlist(config[:emqtt][:username]),
      password: String.to_charlist(config[:emqtt][:password])
    ]
  end
end
