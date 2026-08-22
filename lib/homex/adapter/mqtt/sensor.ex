defmodule Homex.Adapter.MQTT.Sensor do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  @impl Homex.Adapter.MQTT.Platform
  def segments(_desc), do: %{state: []}

  @impl Homex.Adapter.MQTT.Platform
  def component(desc, topics) do
    %{
      platform: "sensor",
      state_topic: topics.state,
      name: desc.name,
      device_class: desc.options[:device_class],
      unit_of_measurement: desc.options[:unit_of_measurement],
      state_class: desc.options[:state_class]
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc, _topics), do: []

  @impl Homex.Adapter.MQTT.Platform
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(_desc, topics, %{state: value}, _changes),
    do: [{topics.state, Homex.encode!(value)}]

  def publish(_desc, _topics, _values, _changes), do: []
end
