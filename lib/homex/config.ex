defmodule Homex.Config do
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

  @moduledoc "#{NimbleOptions.docs(@config_schema)}"

  @typep t() :: %__MODULE__{
           device: map(),
           origin: map(),
           discovery_prefix: String.t(),
           entities: [module()],
           broker: [
             name: atom(),
             host: charlist(),
             port: :inet.port_number(),
             username: charlist(),
             password: charlist()
           ]
         }

  defstruct [:device, :origin, :discovery_prefix, :entities, :broker]

  @doc false
  def get, do: Application.get_all_env(:homex) |> new()

  @doc false
  @spec new(Keyword.t()) :: t()
  def new(opts) do
    config = opts |> NimbleOptions.validate!(@config_schema)

    device = config |> make_device_config()
    origin = config |> make_origin_config()
    broker = config |> make_broker_config()

    %__MODULE__{
      device: device,
      origin: origin,
      broker: broker,
      discovery_prefix: config[:discovery_prefix],
      entities: config[:entities]
    }
  end

  @device_defaults [
    name: {Homex, :hostname, []},
    identifiers: [{Homex, :hostname, []}]
  ]

  defp make_device_config(opts) do
    device = Keyword.get(opts, :device, [])

    @device_defaults
    |> Keyword.merge(device)
    |> map_opts()
    |> Enum.into(%{})
  end

  defp make_origin_config(opts) do
    opts
    |> Keyword.get(:origin, [])
    |> map_opts()
    |> Enum.into(%{})
  end

  defp map_opts(opts) do
    Enum.map(opts, fn
      {key, list} when is_list(list) -> {key, Enum.map(list, &apply_mfa/1)}
      {key, {_, _, _} = mfa} -> {key, apply_mfa(mfa)}
      {key, value} -> {key, value}
    end)
  end

  defp apply_mfa({m, f, a}) when is_atom(m) and is_atom(f) and is_list(a) do
    apply(m, f, a)
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
