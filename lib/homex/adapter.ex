defmodule Homex.Adapter do
  @type name :: atom()
  @callback child_spec({name(), opts :: keyword(), ctx :: map()}) :: Supervisor.child_spec()
  @callback publish_state(name(), descriptor :: Homex.Descriptor.t(), changes :: map()) :: :ok
  @callback entities_changed(name()) :: :ok
end
