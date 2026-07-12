defmodule Homex.Adapter.MQTT.Camera do
  @behaviour Homex.Adapter.MQTT.Platform

  alias Homex.Adapter.MQTT

  @impl Homex.Adapter.MQTT.Platform
  def component(desc) do
    %{
      platform: "camera",
      topic: topic(desc),
      json_attributes_topic: attributes_topic(desc),
      name: desc.name,
      unique_id: desc.unique_id,
      encoding: desc.options[:encoding],
      image_encoding: desc.options[:image_encoding],
      enabled_by_default: desc.options[:enabled_by_default]
    }
  end

  @impl Homex.Adapter.MQTT.Platform
  def subscriptions(_desc), do: []

  @impl Homex.Adapter.MQTT.Platform
  def normalize(_payload), do: nil

  @impl Homex.Adapter.MQTT.Platform
  def publish(desc, changes) do
    Enum.flat_map(changes, fn
      {:image, image} -> [{topic(desc), image}]
      {:attrs, attrs} -> [{attributes_topic(desc), Homex.encode!(attrs)}]
      _ -> []
    end)
  end

  defp topic(desc), do: MQTT.topic(desc)
  defp attributes_topic(desc), do: MQTT.topic(desc, ["attributes"])
end
