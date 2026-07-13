defmodule Homex.Adapter.MQTT.DeviceTrigger do
  @behaviour Homex.Adapter.MQTT.Platform

  alias Homex.Adapter.MQTT

  @impl Homex.Adapter.MQTT.Platform
  def component(desc) do
    %{
      platform: "device_automation",
      automation_type: "trigger",
      name: desc.name,
      unique_id: desc.unique_id,
      type: desc.options[:type],
      subtype: desc.options[:subtype],
      payload: desc.options[:payload],
      topic: topic(desc)
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc), do: []

  @impl Homex.Adapter.MQTT.Platform
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(desc, %{trigger: true}), do: [{topic(desc), desc.options[:payload]}]
  def publish(_desc, _changes), do: []

  defp topic(desc), do: MQTT.topic(desc, ["action"])
end
