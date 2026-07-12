defmodule Homex.Adapter.MQTT.Switch do
  @behaviour Homex.Adapter.MQTT.Platform

  alias Homex.Adapter.MQTT

  @on_payload "ON"
  @off_payload "OFF"

  @impl Homex.Adapter.MQTT.Platform
  def component(desc) do
    %{
      platform: "switch",
      state_topic: state_topic(desc),
      command_topic: command_topic(desc),
      name: desc.name,
      unique_id: desc.unique_id,
      payload_on: @on_payload,
      payload_off: @off_payload
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(desc), do: [command_topic(desc)]

  @impl Homex.Adapter.MQTT.Platform
  def normalize(@on_payload), do: %{state: true}
  def normalize(@off_payload), do: %{state: false}
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(desc, %{state: true}), do: [{state_topic(desc), @on_payload}]
  def publish(desc, %{state: false}), do: [{state_topic(desc), @off_payload}]
  def publish(_desc, _changes), do: []

  defp state_topic(desc), do: MQTT.topic(desc)
  defp command_topic(desc), do: MQTT.topic(desc, ["set"])
end
