defmodule Homex.Entity.SensorTest do
  use ExUnit.Case, async: true
  doctest Homex.Entity.Sensor

  defmodule TestSensor do
    use Homex.Entity.Sensor,
      name: "test-sensor",
      device_class: "temperature",
      unit_of_measurement: Homex.Unit.temperature(:c)
  end

  describe "behaviour" do
    test "platform" do
      assert TestSensor.platform() == "sensor"
    end

    test "config" do
      assert TestSensor.config() == %{
               platform: "sensor",
               state_topic: "homex/sensor/test_sensor",
               name: "test_sensor",
               unique_id: "sensor_test_sensor_6119849",
               unit_of_measurement: "°C",
               device_class: "temperature"
             }
    end
  end
end
