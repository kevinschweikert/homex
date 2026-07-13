defmodule Homex.Adapter.MQTT.Button do
  @behaviour Homex.Adapter.MQTT.Platform

  alias Homex.Adapter.MQTT

  @press_payload "PRESS"

  @impl Homex.Adapter.MQTT.Platform
  def component(desc) do
    %{
      platform: "button",
      name: desc.name,
      unique_id: desc.unique_id,
      device_class: desc.options[:device_class],
      command_topic: command_topic(desc),
      json_attributes_topic: attributes_topic(desc),
      payload_press: @press_payload
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(desc), do: [command_topic(desc)]

  @impl Homex.Adapter.MQTT.Platform
  def normalize(@press_payload), do: %{pressed: true}
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(desc, %{attrs: attrs}), do: [{attributes_topic(desc), Homex.encode!(attrs)}]
  def publish(_desc, _changes), do: []

  defp command_topic(desc), do: MQTT.topic(desc, ["press"])
  defp attributes_topic(desc), do: MQTT.topic(desc, ["attributes"])
end
