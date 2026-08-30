defmodule Homex.Config do
  @config_schema [
                   # TODO: rethink if node_id is really the best name
                   # the node as a concept is already in OTP
                   # maybe instance_id?
                   node_id: [
                     required: true,
                     type: :string,
                     doc: "Identifies this homex instance to Home Assistant."
                   ],
                   devices: [
                     required: false,
                     default: [],
                     type: :keyword_list,
                     doc:
                       "The devices this node exposes, keyed by id. `Homex.Device` lists the options for each one. The `:default` device is always present. It uses the hostname as its name if you do not set one."
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
                         doc: "The name of the application that supplies the entities."
                       ],
                       sw_version: [
                         required: false,
                         type: :string,
                         doc:
                           "The software version of the application that supplies the entities."
                       ],
                       support_url: [
                         required: false,
                         type: :string,
                         doc: "The support URL of the application that supplies the entities."
                       ]
                     ]
                   ],
                   entities: [
                     required: false,
                     default: [],
                     type: {:list, {:or, [:atom, :keyword_list]}}
                   ],
                   adapters: [
                     required: false,
                     default: [],
                     type: {:list, {:or, [:atom, {:tuple, [:atom, :keyword_list]}]}},
                     doc:
                       "The transports to start, as `module` or `{module, opts}`. Each adapter has its own options. See `Homex.Adapter.MQTT` and `Homex.Adapter.ESPHome`. If you give no adapter, the entities still run, but homex does not publish them."
                   ]
                 ]
                 |> NimbleOptions.new!()

  @moduledoc "#{NimbleOptions.docs(@config_schema)}"

  @type t() :: %__MODULE__{
          node_id: String.t(),
          devices: %{Homex.Device.id() => Homex.Device.t()},
          origin: map(),
          entities: [module() | Keyword.t()],
          adapters: [module() | {module(), keyword()}]
        }

  defstruct [:node_id, :devices, :origin, :entities, :adapters]

  @doc false
  @spec new(Keyword.t()) :: t()
  def new(opts) do
    config = opts |> NimbleOptions.validate!(@config_schema)
    origin = config |> make_origin_config()

    %__MODULE__{
      node_id: config[:node_id],
      devices: config |> make_devices_config(),
      origin: origin,
      entities: config[:entities],
      adapters: config[:adapters]
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
end
