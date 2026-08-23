defmodule Homex.Entity.SensorTest do
  use Homex.EntityCase, async: true

  defmodule TestSensor do
    use Homex.Entity.Sensor,
      name: "test-sensor",
      device_class: "temperature",
      unit_of_measurement: "°C"

    @impl Homex.Entity.Sensor
    def handle_info({:set_value, value}, entity), do: set_value(entity, value)
  end

  setup do
    {:ok, entity} = Entity.new(TestSensor)
    start_supervised!({Entity, entity})
    :ok
  end

  test "descriptor carries the sensor options" do
    assert {:ok,
            %Descriptor{
              kind: :sensor,
              name: "test-sensor",
              fields: %{state: :state},
              options: %{device_class: "temperature", unit_of_measurement: "°C"}
            }} = Homex.descriptor("test-sensor")
  end

  test "set_value publishes the committed diff" do
    Homex.notify("test-sensor", {:set_value, 21.5})

    assert_receive {:homex, :state, %Descriptor{kind: :sensor}, _, %{state: 21.5}}
    assert Entity.snapshot("test-sensor") == %{state: 21.5}
  end

  test "an unchanged value is not re-published" do
    Homex.notify("test-sensor", {:set_value, 21.5})
    assert_receive {:homex, :state, _, _, %{state: 21.5}}

    Homex.notify("test-sensor", {:set_value, 21.5})
    refute_receive {:homex, :state, %Descriptor{name: "test-sensor"}, _, _}
  end

  test "sensors ignore inbound commands" do
    Entity.send_command("test-sensor", %{state: 99})
    refute_receive {:homex, :state, %Descriptor{name: "test-sensor"}, _, _}
  end

  describe "set_value/2" do
    alias Homex.Entity.Sensor

    test "records the typed value as a change" do
      {:ok, entity} = Sensor.new(name: "fn-sensor")
      assert Sensor.set_value(entity, 21.5).changes == %{state: 21.5}
    end
  end
end
