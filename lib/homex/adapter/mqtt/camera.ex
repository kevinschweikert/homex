defmodule Homex.Adapter.MQTT.Camera do
  @moduledoc false
  @behaviour Homex.Adapter.MQTT.Platform

  @impl Homex.Adapter.MQTT.Platform
  def segments(_desc), do: %{image: [], attributes: ["attributes"]}

  @impl Homex.Adapter.MQTT.Platform
  def component(desc, topics) do
    %{
      platform: "camera",
      topic: topics.image,
      json_attributes_topic: topics.attributes,
      name: desc.name,
      encoding: desc.options[:encoding],
      image_encoding: desc.options[:image_encoding],
      enabled_by_default: desc.options[:enabled_by_default]
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc, _topics), do: []

  @impl Homex.Adapter.MQTT.Platform
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(_desc, topics, changes) do
    Enum.flat_map(changes, fn
      {:image, image} -> [{topics.image, image}]
      {:attrs, attrs} -> [{topics.attributes, Homex.encode!(attrs)}]
      _ -> []
    end)
  end
end
