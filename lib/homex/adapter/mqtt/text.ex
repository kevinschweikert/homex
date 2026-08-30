defmodule Homex.Adapter.MQTT.Text do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  alias Homex.Descriptor

  @impl Homex.Adapter.MQTT.Platform
  def segments(_desc), do: %{cmd: ["cmd"], state: ["state"], attributes: ["attributes"]}

  @impl Homex.Adapter.MQTT.Platform
  def component(%Descriptor{options: options} = desc, topics) do
    %{
      platform: "text",
      state_topic: topics.state,
      command_topic: topics.cmd,
      json_attributes_topic: topics.attributes,
      name: desc.name,
      enabled_by_default: options.enabled_by_default,
      visible_by_default: options.visible_by_default,
      min: options.min,
      max: options.max,
      mode: options.mode,
      pattern: options.pattern
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc, topics), do: [topics.cmd]

  @impl Homex.Adapter.MQTT.Platform
  def normalize(text), do: %{state: text}

  @impl Homex.Adapter.MQTT.Platform
  def publish(_desc, topics, _values, changes) do
    Enum.flat_map(changes, fn
      {:state, text} -> [{topics.state, text}]
      {:attrs, attrs} -> [{topics.attributes, Homex.encode!(attrs)}]
      _ -> []
    end)
  end
end
