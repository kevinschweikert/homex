defmodule Homex.Descriptor do
  @moduledoc """
  The canonical description of an entity inside homex.

  A kind builds one in its `c:Homex.Entity.describe/1` callback. The adapters read
  it to publish the entity. `Homex.descriptor/1` and `Homex.descriptors/0` give
  the descriptors of the running entities.

    * `:kind` - The entity kind, for example `:sensor`. Each adapter uses it to
      select the platform module that serves the entity.
    * `:name` - The unique name of the entity. Homex registers the entity under
      this name. The adapters make the Home Assistant identifiers from it.
    * `:device` - The id of the `Homex.Device` that the entity belongs to.
    * `:fields` - The value keys of the entity, and the type of each key. Homex
      publishes a `:state` key only when the value changes. It publishes an
      `:event` key on each commit, because two equal events are still two events.
    * `:options` - The settings that only this kind has. The adapters put them in
      the Home Assistant configuration.
    * `:transport` - Options for one adapter, keyed by adapter.

  ## Example

      %Homex.Descriptor{
        kind: :sensor,
        name: "living-room-temperature",
        device: :default,
        fields: %{state: :state},
        options: %{
          device_class: "temperature",
          unit_of_measurement: "°C",
          state_class: "measurement"
        },
        transport: %{mqtt: [retain: true]}
      }
  """

  # TODO:
  # evaluate if maybe name should be an atom
  # and also be named entity_id so it mirrors node_id

  @type t() :: %__MODULE__{
          kind: atom(),
          fields: %{atom() => :state | :event},
          name: String.t(),
          device: atom(),
          options: map(),
          transport: map()
        }

  defstruct [
    :kind,
    :fields,
    :name,
    :device,
    :options,
    :transport
  ]
end
