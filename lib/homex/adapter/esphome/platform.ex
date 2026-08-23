defmodule Homex.Adapter.ESPHome.Platform do
  @moduledoc false

  import Homex.Util, only: [slug: 1]

  alias Homex.Descriptor

  # an esphome entity key is a uint32
  @key_space 2 ** 32

  @doc "The kind specific fields of the `Espex.Proto.ListEntities*Response` advertising the entity"
  @callback list_entity(Descriptor.t()) :: struct()

  @doc """
  The `Espex.Proto.*StateResponse` frame carrying the current values, or `nil` for
  a kind the native API has no state frame for, such as a button
  """
  @callback state(Descriptor.t(), values :: map()) :: struct() | nil

  @doc "The homex command a client request translates to, `nil` when the platform ignores it"
  @callback command(request :: struct()) :: map() | nil

  @doc """
  The key Home Assistant identifies the entity by.

  Same contract as `Homex.Adapter.MQTT.Util.component_identifier/2`: if it changes,
  Home Assistant recognizes the entity as a new one and the old one goes stale.
  """
  def key(name) when is_binary(name), do: :erlang.phash2({Homex.node_id(), name}, @key_space)

  @doc """
  The advertisement for one entity.

  A platform fills only its own fields — the identity every kind shares is added
  here, so an advertisement and the state frames can not disagree on the key.
  """
  def list_entity(module, %Descriptor{name: name} = descriptor) do
    struct(module.list_entity(descriptor), object_id: slug(name), key: key(name), name: name)
  end

  @doc """
  The state frame for one entity, under the same key as its advertisement.

  `nil` for a kind without a platform as much as for one with nothing to report.
  """
  def state(nil, _descriptor, _values), do: nil

  def state(module, %Descriptor{name: name} = descriptor, values) do
    case module.state(descriptor, values) do
      nil -> nil
      frame -> %{frame | key: key(name)}
    end
  end
end
