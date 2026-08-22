defmodule Homex.Adapter.MQTT.Util do
  alias Homex.Descriptor
  alias Homex.Device

  @doc """
  This is the id, Homeassistant identifies the entity. If it changes, Homeassistant recognizes
  entity as a new one and the old one goes stale.
  """

  def component_identifier(node_id, %Descriptor{name: name})
      when is_binary(name) and is_binary(node_id) do
    hash = :erlang.phash2([name, node_id])
    "homex-#{slug(node_id)}-#{slug(name)}-#{hash}"
  end

  # HA identifies a device by its identifiers, so they are scoped by the node id —
  # unique per homex instance, stable across renames of the device itself.
  def device_identifier(node_id, %Device{id: id}) when is_binary(node_id) do
    "homex-#{slug(node_id)}-#{id}"
  end

  def slug(binary) when is_binary(binary) do
    binary
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "_")
    |> String.trim("_")
  end

  @doc """
  Returns the identifier of the component and the function its topics are built with.

  Both come from one computation, so the discovery config and the topics can not
  disagree. The platform only names the segments below the component, the prefix
  stays here.
  """
  @typedoc "Makes a topic of the component from a list of segments"
  @type topic_builder() :: ([String.t()] -> String.t())

  @spec identity(String.t(), Descriptor.t()) :: {String.t(), topic_builder()}
  def identity(node_id, %Descriptor{kind: kind} = descriptor) do
    identifier = component_identifier(node_id, descriptor)
    {identifier, &topic(["homex", kind, identifier], &1)}
  end

  defp topic(prefix, segments) when is_list(segments) do
    prefix
    |> Enum.concat(segments)
    |> Enum.join("/")
  end
end
