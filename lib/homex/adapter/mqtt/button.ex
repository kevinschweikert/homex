defmodule Homex.Adapter.MQTT.Button do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  @press_payload "PRESS"

  @impl Homex.Adapter.MQTT.Platform
  def segments(_desc), do: %{command: ["press"], attributes: ["attributes"]}

  @impl Homex.Adapter.MQTT.Platform
  def component(desc, topics) do
    %{
      platform: "button",
      name: desc.name,
      device_class: desc.options[:device_class],
      command_topic: topics.command,
      json_attributes_topic: topics.attributes,
      payload_press: @press_payload
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc, topics), do: [topics.command]

  @impl Homex.Adapter.MQTT.Platform
  def normalize(@press_payload), do: %{pressed: true}
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(_desc, topics, %{attrs: attrs}), do: [{topics.attributes, Homex.encode!(attrs)}]
  def publish(_desc, _topics, _changes), do: []
end
