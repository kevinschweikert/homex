defmodule Homex.Adapter.MQTT.Number do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  alias Homex.Descriptor

  @impl Homex.Adapter.MQTT.Platform
  def segments(_desc), do: %{state: [], command: ["set"]}

  @impl Homex.Adapter.MQTT.Platform
  def component(%Descriptor{options: options} = desc, topics) do
    %{
      platform: "number",
      state_topic: topics.state,
      command_topic: topics.command,
      name: desc.name,
      enabled_by_default: options.enabled_by_default,
      visible_by_default: options.visible_by_default,
      min: options.min,
      max: options.max,
      step: options.step,
      mode: options.mode,
      unit_of_measurement: options.unit_of_measurement,
      device_class: options.device_class
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc, topics), do: [topics.command]

  @impl Homex.Adapter.MQTT.Platform
  def normalize(payload) do
    case Float.parse(payload) do
      {value, ""} -> %{state: value}
      _ -> nil
    end
  end

  @impl Homex.Adapter.MQTT.Platform
  def publish(_desc, topics, %{state: value}, _changes),
    do: [{topics.state, Homex.encode!(value)}]

  def publish(_desc, _topics, _values, _changes), do: []
end
