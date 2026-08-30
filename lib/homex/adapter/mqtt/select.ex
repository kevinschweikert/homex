defmodule Homex.Adapter.MQTT.Select do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  alias Homex.Descriptor

  @impl Homex.Adapter.MQTT.Platform
  def segments(_desc), do: %{state: [], command: ["set"]}

  @impl Homex.Adapter.MQTT.Platform
  def component(%Descriptor{options: options} = desc, topics) do
    %{
      platform: "select",
      state_topic: topics.state,
      command_topic: topics.command,
      name: desc.name,
      enabled_by_default: options.enabled_by_default,
      visible_by_default: options.visible_by_default,
      options: options.options
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc, topics), do: [topics.command]

  @impl Homex.Adapter.MQTT.Platform
  def normalize(option), do: %{state: option}

  @impl Homex.Adapter.MQTT.Platform
  def publish(_desc, topics, %{state: option}, _changes), do: [{topics.state, option}]

  def publish(_desc, _topics, _values, _changes), do: []
end
