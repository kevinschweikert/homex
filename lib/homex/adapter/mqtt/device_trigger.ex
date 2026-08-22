defmodule Homex.Adapter.MQTT.DeviceTrigger do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  @impl Homex.Adapter.MQTT.Platform
  def segments(_desc), do: %{action: ["action"]}

  @impl Homex.Adapter.MQTT.Platform
  def component(desc, topics) do
    %{
      platform: "device_automation",
      automation_type: "trigger",
      name: desc.name,
      type: desc.options[:type],
      subtype: desc.options[:subtype],
      payload: desc.options[:payload],
      topic: topics.action
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc, _topics), do: []

  @impl Homex.Adapter.MQTT.Platform
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(desc, topics, _values, %{trigger: true}),
    do: [{topics.action, desc.options[:payload]}]

  def publish(_desc, _topics, _values, _changes), do: []
end
