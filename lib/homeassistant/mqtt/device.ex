defmodule Homeassistant.MQTT.Device do
  @moduledoc """
  A device struct
  """

  @type t() :: %__MODULE__{
          identifiers: [String.t()],
          name: String.t(),
          manufacturer: String.t(),
          model: String.t(),
          sw_version: String.t(),
          hw_version: String.t(),
          serial_number: String.t()
        }

  @derive Jason.Encoder

  defstruct [
    :identifiers,
    :name,
    :manufacturer,
    :model,
    :sw_version,
    :hw_version,
    :serial_number
  ]
end
