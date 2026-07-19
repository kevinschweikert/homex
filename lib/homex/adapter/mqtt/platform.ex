defmodule Homex.Adapter.MQTT.Platform do
  @moduledoc false
  @callback component(Homex.Descriptor.t()) :: map()
  @callback subscriptions(Homex.Descriptor.t()) :: [String.t()]
  @callback normalize(payload :: term()) :: map() | nil
  @callback publish(Homex.Descriptor.t(), changes :: map()) ::
              [{topic :: String.t(), payload :: iodata()}]
end
