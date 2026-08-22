defmodule Homex.Adapter.MQTT.Switch do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  @on_payload "ON"
  @off_payload "OFF"

  @impl Homex.Adapter.MQTT.Platform
  def segments(_desc), do: %{state: [], command: ["set"]}

  @impl Homex.Adapter.MQTT.Platform
  def component(desc, topics) do
    %{
      platform: "switch",
      state_topic: topics.state,
      command_topic: topics.command,
      name: desc.name,
      payload_on: @on_payload,
      payload_off: @off_payload
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc, topics), do: [topics.command]

  @impl Homex.Adapter.MQTT.Platform
  def normalize(@on_payload), do: %{state: true}
  def normalize(@off_payload), do: %{state: false}
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(_desc, topics, %{state: true}, _changes), do: [{topics.state, @on_payload}]
  def publish(_desc, topics, %{state: false}, _changes), do: [{topics.state, @off_payload}]
  def publish(_desc, _topics, _values, _changes), do: []
end
