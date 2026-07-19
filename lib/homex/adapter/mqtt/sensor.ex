defmodule Homex.Adapter.MQTT.Sensor do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  alias Homex.Adapter.MQTT

  @impl Homex.Adapter.MQTT.Platform
  def component(desc) do
    %{
      platform: "sensor",
      state_topic: state_topic(desc),
      name: desc.name,
      unique_id: desc.unique_id,
      device_class: desc.options[:device_class],
      unit_of_measurement: desc.options[:unit_of_measurement],
      state_class: desc.options[:state_class]
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc), do: []

  @impl Homex.Adapter.MQTT.Platform
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(desc, %{state: value}), do: [{state_topic(desc), Homex.encode!(value)}]
  def publish(_desc, _changes), do: []

  defp state_topic(desc), do: MQTT.topic(desc)
end
