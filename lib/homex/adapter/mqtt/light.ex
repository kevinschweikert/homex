defmodule Homex.Adapter.MQTT.Light do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  @impl Homex.Adapter.MQTT.Platform
  def segments(_desc), do: %{state: [], command: ["set"]}

  @impl Homex.Adapter.MQTT.Platform
  def component(desc, topics) do
    modes = desc.options[:modes] || []

    base = %{
      platform: "light",
      schema: "json",
      state_topic: topics.state,
      command_topic: topics.command,
      name: desc.name,
      supported_color_modes: color_modes(modes)
    }

    if :brightness in modes or :rgb in modes, do: Map.put(base, :brightness, true), else: base
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc, topics), do: [topics.command]

  @impl Homex.Adapter.MQTT.Platform
  def normalize(payload) when is_binary(payload) do
    case Homex.decode(payload) do
      {:ok, decoded} -> from_wire(decoded)
      _ -> nil
    end
  end

  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  # ha reads a json light message as a full snapshot, so the state goes into every
  # message, also when only the brightness changed
  def publish(_desc, topics, values, _changes) do
    case wire_state(values[:state]) do
      nil ->
        []

      state ->
        payload =
          %{"state" => state}
          |> maybe_put("brightness", values[:brightness], &wire_brightness/1)
          |> put_color(values[:mode], values[:color])

        [{topics.state, Homex.encode!(payload)}]
    end
  end

  # ha rejects onoff or brightness alongside a real colour mode, so only the
  # richest one is advertised
  defp color_modes(modes) do
    cond do
      :rgb in modes -> ["rgb"]
      :brightness in modes -> ["brightness"]
      true -> ["onoff"]
    end
  end

  defp put_color(payload, :rgb, {:rgb, r, g, b}) do
    payload
    |> Map.put("color_mode", "rgb")
    |> Map.put("color", %{
      "r" => wire_component(r),
      "g" => wire_component(g),
      "b" => wire_component(b)
    })
  end

  defp put_color(payload, _mode, _color), do: payload

  defp from_wire(map) do
    %{}
    |> maybe_put(:state, map["state"], &core_state/1)
    |> maybe_put(:brightness, map["brightness"], &core_brightness/1)
    |> maybe_put(:color, map["color"], &core_color/1)
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

  defp core_brightness(value) when is_number(value), do: core_component(value)
  defp core_brightness(_), do: nil

  defp core_color(%{"r" => r, "g" => g, "b" => b})
       when is_number(r) and is_number(g) and is_number(b),
       do: {:rgb, core_component(r), core_component(g), core_component(b)}

  defp core_color(_), do: nil

  # the payload comes off the wire, so it is clamped before it reaches a setter
  # that raises outside 0..1
  defp core_component(value),
    do: value |> max(0) |> min(255) |> Kernel./(255) |> Float.round(4)

  defp wire_state(true), do: "ON"
  defp wire_state(false), do: "OFF"
  defp wire_state(_), do: nil

  defp wire_brightness(value), do: round(value * 255)
  defp wire_component(value), do: round(value * 255)
end
