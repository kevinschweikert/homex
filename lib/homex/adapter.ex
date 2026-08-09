defmodule Homex.Adapter do
  @moduledoc """
  Behaviour for transports that connect Homex entities to the outside world.

  An adapter receives the committed state changes of running entities and is
  notified whenever entities are added or removed. `Homex.Adapter.MQTT`
  (Home Assistant MQTT discovery) is the built-in implementation.

  Running adapters are returned by `Homex.adapters/0` as `{module, instance}`
  pairs; the instance name is passed back as the first argument of every
  callback, so a module can serve multiple instances.
  """

  @typedoc "Identifies an adapter instance, usually its registered process name"
  @type name :: atom()

  @doc """
  Builds the child spec that starts the adapter instance under the Homex
  supervision tree, from its instance name, its options and the shared
  context (e.g. device info).
  """
  @callback child_spec({name(), opts :: keyword(), ctx :: map()}) :: Supervisor.child_spec()

  @doc """
  Delivers the committed state diff of an entity.

  Called after every entity change commit with the entity's descriptor and a
  map of the fields that actually changed.
  """
  @callback publish_state(name(), descriptor :: Homex.Descriptor.t(), changes :: map()) :: :ok

  @doc """
  Signals that entities were added or removed, so the adapter can update
  announcements and subscriptions.
  """
  @callback entities_changed(name()) :: :ok
end
