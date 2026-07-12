defmodule Homex.Adapter.MQTT.Light do
  @behaviour Homex.Adapter.MQTT.Platform

  alias Homex.Adapter.MQTT

  @impl Homex.Adapter.MQTT.Platform
  def component(desc) do
    modes = desc.options[:modes] || []

    base = %{
      platform: "light",
      schema: "json",
      state_topic: state_topic(desc),
      command_topic: command_topic(desc),
      name: desc.name,
      unique_id: desc.unique_id,
      supported_color_modes: color_modes(modes)
    }

    if :brightness in modes, do: Map.put(base, :brightness, true), else: base
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(desc), do: [command_topic(desc)]

  @impl Homex.Adapter.MQTT.Platform
  def normalize(payload) when is_binary(payload) do
    case Homex.decode(payload) do
      {:ok, decoded} -> from_wire(decoded)
      _ -> nil
    end
  end

  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(desc, changes) do
    payload =
      %{}
      |> maybe_put("state", changes[:state], &wire_state/1)
      |> maybe_put("brightness", changes[:brightness], &wire_brightness/1)

    if payload == %{}, do: [], else: [{state_topic(desc), Homex.encode!(payload)}]
  end

  defp state_topic(desc), do: MQTT.topic(desc)
  defp command_topic(desc), do: MQTT.topic(desc, ["set"])

  defp color_modes(modes), do: if(:brightness in modes, do: ["brightness"], else: ["onoff"])

  defp from_wire(map) do
    %{}
    |> maybe_put(:state, map["state"], &core_state/1)
    |> maybe_put(:brightness, map["brightness"], &core_brightness/1)
  end

  defp maybe_put(map, _key, nil, _fun), do: map

  defp maybe_put(map, key, value, fun) do
    case fun.(value) do
      nil -> map
      converted -> Map.put(map, key, converted)
    end
  end

  defp core_state("ON"), do: true
  defp core_state("OFF"), do: false
  defp core_state(_), do: nil

  defp core_brightness(value) when is_number(value),
    do: value |> max(0) |> min(255) |> Kernel.*(100) |> Kernel./(255) |> Float.round(2)

  defp core_brightness(_), do: nil

  defp wire_state(true), do: "ON"
  defp wire_state(false), do: "OFF"

  defp wire_brightness(value), do: round(value / 100 * 255)
end
