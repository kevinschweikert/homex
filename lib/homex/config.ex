defmodule Homex.Config do
  @config_schema [
                   # TODO: rethink if node_id is really the best name
                   # the node as a concept is already in OTP
                   # maybe instance_id?
                   node_id: [
                     required: true,
                     type: :string,
                     doc: "identifies this Homex instance for HA"
                   ],
                   devices: [
                     required: false,
                     default: [],
                     type: :keyword_list,
                     doc:
                       "Devices this node exposes, keyed by id, with the options from `Homex.Device`. The `:default` device is always present and takes its name from the hostname unless configured."
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
                   entities: [
                     required: false,
                     default: [],
                     type: {:list, {:or, [:atom, :keyword_list]}}
                   ],
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

  @moduledoc "#{NimbleOptions.docs(@config_schema)}"

  @type t() :: %__MODULE__{
          node_id: String.t(),
          devices: %{Homex.Device.id() => Homex.Device.t()},
          origin: map(),
          discovery_prefix: String.t(),
          entities: [module() | Keyword.t()],
          broker: [
            name: atom(),
            host: charlist(),
            port: :inet.port_number(),
            username: charlist(),
            password: charlist()
          ]
        }

  defstruct [:node_id, :devices, :origin, :discovery_prefix, :entities, :broker]

  @doc false
  @spec new(Keyword.t()) :: t()
  def new(opts) do
    config = opts |> NimbleOptions.validate!(@config_schema)
    origin = config |> make_origin_config()
    broker = config |> make_broker_config()

    %__MODULE__{
      node_id: config[:node_id],
      devices: config |> make_devices_config(),
      origin: origin,
      broker: broker,
      discovery_prefix: config[:discovery_prefix],
      entities: config[:entities]
    }
  end

  @device_defaults [default: [name: {Homex, :hostname, []}]]

  defp make_devices_config(opts) do
    @device_defaults
    |> Keyword.merge(Keyword.fetch!(opts, :devices), fn _id, defaults, device_opts ->
      Keyword.merge(defaults, device_opts)
    end)
    |> Map.new(fn {id, device_opts} ->
      {:ok, device} = Homex.Device.new(id, device_opts)
      {id, device}
    end)
  end

  defp make_origin_config(opts) do
    opts |> Keyword.fetch!(:origin) |> Map.new()
  end

  defp make_broker_config(opts) do
    config =
      opts
      |> Keyword.get(:broker, [])

    [
      name: Homex.EMQTT,
      host: String.to_charlist(config[:host]),
      port: config[:port],
      username: optional(config[:username], &String.to_charlist/1),
      password: optional(config[:password], &String.to_charlist/1)
    ]
    |> Keyword.reject(fn {_key, val} -> is_nil(val) end)
  end

  defp optional(val, _) when is_nil(val), do: nil
  defp optional(val, transformer), do: transformer.(val)
end
