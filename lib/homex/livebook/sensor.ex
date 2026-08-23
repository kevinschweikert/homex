defmodule Homex.Livebook.Sensor do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @icons %{
    "temperature" => "🌡️",
    "humidity" => "💧",
    "pressure" => "🧭",
    "battery" => "🔋",
    "power" => "🔆"
  }

  @impl Kind
  def card(%{options: options}, %{state: value}, _changes) do
    %{
      icon: @icons[options[:device_class]] || "📈",
      value: Kind.format(value),
      unit: options[:unit_of_measurement],
      sub: options[:device_class] || "sensor"
    }
  end
end
