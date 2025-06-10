defmodule Homeassistant.MQTT.Origin do
  @moduledoc """
  A component struct
  """

  @type t() :: %__MODULE__{
          name: String.t(),
          sw_version: String.t(),
          support_url: String.t() | URI.t()
        }

  @derive Jason.Encoder

  defstruct [
    :name,
    :sw_version,
    :support_url
  ]
end
