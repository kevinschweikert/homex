defmodule Homex.Adapter.ESPHome.Platform do
  @moduledoc false

  import Homex.Util, only: [slug: 1]

  alias Homex.Descriptor

  # an esphome entity key is a uint32
  @key_space 2 ** 32

  @doc "The fields that only this entity kind has, for its `Espex.Proto.ListEntities*Response`"
  @callback list_entity(Descriptor.t()) :: struct()

  @doc """
  The espex sub-device id for a `Homex.Device`.

  `:default` is the node itself. The native API shows the node as `device_id: 0`.
  """
  def device_id(:default), do: 0

  def device_id(device_id) when is_atom(device_id) do
    1 + :erlang.phash2({Homex.instance_id(), device_id}, @key_space - 1)
  end

  @doc """
  The `Espex.Proto.*StateResponse` frame with the current values.

  Gives `nil` for an entity kind that has no state frame, for example a button.
  """
  @callback state(Descriptor.t(), values :: map()) :: struct() | nil

  @doc "The homex command for a client request. Gives `nil` if the platform ignores it"
  @callback command(request :: struct()) :: map() | nil

  @doc """
  The key that Home Assistant uses to identify the entity.

  If the key changes, Home Assistant makes a new entity and the old entity becomes
  stale. `Homex.Adapter.MQTT.Util.component_identifier/2` has the same contract.
  """
  def key(id) when is_atom(id), do: :erlang.phash2({Homex.instance_id(), id}, @key_space)

  @doc """
  The advertisement for one entity.

  A platform gives only its own fields. This function adds the identity that all
  kinds share. Because of this, the advertisement and the state frames always use
  the same key.
  """
  def list_entity(module, %Descriptor{id: id, name: name, device: device} = descriptor) do
    struct(module.list_entity(descriptor),
      object_id: slug(name),
      key: key(id),
      name: name,
      device_id: device_id(device)
    )
  end

  @doc """
  The state frame for one entity. It uses the same key as the advertisement.

  Gives `nil` for an entity kind that has no platform, and for a platform that has
  no data to report.
  """
  def state(nil, _descriptor, _values), do: nil

  def state(module, %Descriptor{id: id} = descriptor, values) do
    case module.state(descriptor, values) do
      nil -> nil
      frame -> %{frame | key: key(id)}
    end
  end
end
