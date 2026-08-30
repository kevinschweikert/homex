defmodule Homex.Adapter.ESPHome.EspexTree do
  @moduledoc false

  # separate from the adapter so `Reloader` can restart this tree without stopping itself

  use Supervisor

  alias Espex.DeviceConfig
  alias Homex.Adapter.ESPHome.{EntityProvider, Platform}

  # espex calls EntityProvider as a bare module, so only one instance of this
  # tree can run per VM
  @server __MODULE__.Server
  @supervisor __MODULE__.Supervisor

  def start_link(opts), do: Supervisor.start_link(__MODULE__, opts)

  @impl Supervisor
  def init(opts) do
    children = [
      {EntityProvider, server: @server},
      {Espex, espex_opts(opts)}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end

  defp espex_opts(opts) do
    [
      name: @supervisor,
      server_name: @server,
      entity_provider: EntityProvider,
      port: opts[:port],
      mdns: opts[:mdns],
      device_config: device_config(Homex.devices())
    ]
    |> Keyword.reject(fn {_key, val} -> is_nil(val) end)
    |> Keyword.merge(opts[:espex_opts], &merge_nested/3)
  end

  @doc false
  # :default is the node itself, all other devices become flat sub-devices
  @spec device_config(%{Homex.Device.id() => Homex.Device.t()}) :: keyword()
  def device_config(devices) do
    default = Map.fetch!(devices, :default)

    sub_devices =
      for {id, device} <- devices, id != :default do
        DeviceConfig.Device.new(id: Platform.device_id(id), name: device.name)
      end

    [
      name: Homex.node_id(),
      friendly_name: default.name,
      manufacturer: default.manufacturer,
      model: default.model,
      devices: sub_devices
    ]
    |> Keyword.reject(fn {_key, val} -> is_nil(val) end)
  end

  defp merge_nested(_key, derived, override) do
    if Keyword.keyword?(derived) and Keyword.keyword?(override),
      do: Keyword.merge(derived, override),
      else: override
  end
end
