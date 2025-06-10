defmodule Homeassistant.MQTT.Component do
  @moduledoc """
  A component struct
  """

  @type t() :: %__MODULE__{
          platform: String.t(),
          device_class: String.t(),
          unit_of_measurement: String.t(),
          value_template: String.t(),
          unique_id: String.t()
        }

  @derive Jason.Encoder

  defstruct [
    :platform,
    :device_class,
    :unit_of_measurement,
    :value_template,
    :unique_id
  ]
end
