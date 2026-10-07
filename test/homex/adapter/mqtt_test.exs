defmodule Homex.Adapter.MQTTTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Homex.Adapter.MQTT

  @devices Homex.Config.new(
             id: "mqtt-test",
             devices: [
               default: [name: "Node", manufacturer: "acme"],
               kitchen: [name: "Kitchen", via: :default],
               orphan: [via: :nowhere]
             ]
           ).devices

  defp device_config(id), do: MQTT.device_config("node", @devices, @devices[id])

  test "root device is projected with its metadata and no via_device" do
    assert device_config(:default) == %{
             name: "Node",
             identifiers: ["homex-node-default"],
             manufacturer: "acme"
           }
  end

  test "sub device links to the parent by its identifier" do
    assert device_config(:kitchen) == %{
             name: "Kitchen",
             identifiers: ["homex-node-kitchen"],
             via_device: "homex-node-default"
           }
  end

  test "dangling via is dropped with a warning" do
    log = capture_log(fn -> refute device_config(:orphan)[:via_device] end)
    assert log =~ ":nowhere"
  end

  describe "state_messages/4" do
    test "a switch publishes its state on its state topic with the retain option" do
      descriptor = descriptor(Homex.Entity.Switch, id: :test_switch, name: "Test")
      values = %{state: false}

      assert [{topic, "OFF", [retain: true]}] =
               MQTT.state_messages("node", descriptor, values, values)

      assert topic == "homex/switch/" <> MQTT.Util.component_identifier("node", descriptor)
    end

    test "an entity that holds no value publishes nothing" do
      descriptor = descriptor(Homex.Entity.Sensor, id: :test_sensor, name: "Test")
      assert MQTT.state_messages("node", descriptor, %{}, %{}) == []
    end
  end

  defp descriptor(kind, opts) do
    {:ok, validated} = kind.validate(opts)
    %{kind.describe(validated) | id: validated[:id], device: validated[:device]}
  end
end
