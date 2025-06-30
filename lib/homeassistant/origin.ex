defmodule Homeassistant.MQTT.Origin do
  @moduledoc """
  A component struct
  """

  @type t() :: %__MODULE__{
          name: String.t(),
          sw_version: String.t(),
          support_url: String.t() | URI.t()
        }

  @enforce_keys [:name]
  defstruct [
    :name,
    :sw_version,
    :support_url
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
