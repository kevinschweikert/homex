defmodule Homex.Adapter.MQTT.Platform do
  @moduledoc false

  @typedoc "The topic segments below the prefix of the component, by key"
  @type segments() :: %{atom() => [String.t()]}

  @typedoc "The resolved topics of the component, under the same keys"
  @type topics() :: %{atom() => String.t()}

  @callback segments(Homex.Descriptor.t()) :: segments()
  @callback component(Homex.Descriptor.t(), topics()) :: map()
  @callback subscriptions(Homex.Descriptor.t(), topics()) :: [String.t()]
  @callback normalize(payload :: term()) :: map() | nil
  @callback publish(Homex.Descriptor.t(), topics(), values :: map(), changes :: map()) ::
              [{topic :: String.t(), payload :: iodata()}]
end
