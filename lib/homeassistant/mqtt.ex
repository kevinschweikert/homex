defmodule Homeassistant.MQTT do
  @moduledoc """
  The base struct for the discovery packet
  """

  alias Homeassistant.MQTT.Device
  alias Homeassistant.MQTT.Origin
  alias Homeassistant.MQTT.Component

  @type t() :: %__MODULE__{
          device: Device.t(),
          origin: Origin.t(),
          components: %{optional(String.t()) => Component.t()},
          availability: Availability.t(),
          state_topic: String.t(),
          command_topic: String.t(),
          qos: pos_integer(),
          encoding: String.t()
        }

  defstruct [
    :device,
    :origin,
    :availability,
    :components,
    :state_topic,
    :command_topic,
    :qos,
    encoding: "utf-8"
  ]

  defimpl Jason.Encoder do
    def encode(value, opts) do
      value
      |> Map.from_struct()
      |> Map.reject(fn {k, v} -> k not in [:identifiers] and is_nil(v) end)
      |> Jason.Encode.map(opts)
    end
  end
end
