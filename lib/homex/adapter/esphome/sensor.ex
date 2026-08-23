defmodule Homex.Adapter.ESPHome.Sensor do
  @moduledoc false

  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform

  @behaviour Platform

  # the homex option is the Home Assistant string, the proto field is an enum
  @state_classes %{
    "measurement" => :STATE_CLASS_MEASUREMENT,
    "total" => :STATE_CLASS_TOTAL,
    "total_increasing" => :STATE_CLASS_TOTAL_INCREASING,
    "measurement_angle" => :STATE_CLASS_MEASUREMENT_ANGLE
  }

  # Home Assistant rounds the reading to this many decimals, and the proto default
  # of 0 would show whole numbers only. Until the sensor kind carries a precision
  # of its own, this is what an esphome sensor defaults to
  @accuracy_decimals 1

  @impl Platform
  def list_entity(%{options: options}) do
    %Proto.ListEntitiesSensorResponse{
      unit_of_measurement: options.unit_of_measurement,
      device_class: options.device_class,
      state_class: Map.get(@state_classes, options.state_class, :STATE_CLASS_NONE),
      accuracy_decimals: @accuracy_decimals
    }
  end

  # a sensor that has not measured yet reads as unknown in Home Assistant rather
  # than as the zero the proto field would otherwise carry
  @impl Platform
  def state(_descriptor, %{state: nil}), do: %Proto.SensorStateResponse{missing_state: true}
  def state(_descriptor, %{state: state}), do: %Proto.SensorStateResponse{state: state}

  @impl Platform
  def command(_request), do: nil
end
