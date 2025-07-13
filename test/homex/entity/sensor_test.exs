defmodule Homex.Entity.SensorTest do
  use ExUnit.Case, async: true
  doctest Homex.Entity.Sensor

  defmodule TestSensor do
    use Homex.Entity.Sensor,
      name: "test-sensor",
      device_class: "temperature",
      unit_of_measurement: "°C"
  end

  describe "behaviour" do
    test "platform" do
      assert TestSensor.platform() == "sensor"
    end

    test "config" do
      assert TestSensor.config() == %{
               platform: "sensor",
               state_topic: "homex/sensor/#{TestSensor.unique_id()}",
               name: "test-sensor",
               unique_id: "#{TestSensor.unique_id()}",
               unit_of_measurement: "°C",
               device_class: "temperature"
             }
    end
  end
end
