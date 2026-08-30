defmodule Homex.Adapter.MQTT.Util do
  @moduledoc false

  import Homex.Util, only: [slug: 1]

  alias Homex.Descriptor
  alias Homex.Device

  @doc """
  This is the id, Homeassistant identifies the entity. If it changes, Homeassistant recognizes
  entity as a new one and the old one goes stale.
  """

  def component_identifier(instance_id, %Descriptor{id: id})
      when is_atom(id) and is_binary(instance_id) do
    hash = :erlang.phash2([id, instance_id])
    "homex-#{slug(instance_id)}-#{slug(to_string(id))}-#{hash}"
  end

  # HA identifies a device by its identifiers, so they are scoped by the instance
  # id — unique per homex instance, stable across renames of the device itself.
  def device_identifier(instance_id, %Device{id: id}) when is_binary(instance_id) do
    "homex-#{slug(instance_id)}-#{id}"
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
  def identity(instance_id, %Descriptor{kind: kind} = descriptor) do
    identifier = component_identifier(instance_id, descriptor)
    {identifier, &topic(["homex", kind, identifier], &1)}
  end

  defp topic(prefix, segments) when is_list(segments) do
    prefix
    |> Enum.concat(segments)
    |> Enum.join("/")
  end
end
