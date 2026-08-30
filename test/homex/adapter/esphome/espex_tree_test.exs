defmodule Homex.Adapter.ESPHome.EspexTreeTest do
  use ExUnit.Case, async: true

  alias Homex.Adapter.ESPHome.{EspexTree, Platform}

  @devices Homex.Config.new(
             node_id: "esphome-test",
             devices: [
               default: [name: "Node", manufacturer: "acme", model: "Homex"],
               kitchen: [name: "Kitchen"]
             ]
           ).devices

  test "the default device supplies the node's own identity" do
    assert %{friendly_name: "Node", manufacturer: "acme", model: "Homex"} =
             Map.new(EspexTree.device_config(@devices))
  end

  test "any other device becomes a flat espex sub-device" do
    assert [%Espex.DeviceConfig.Device{name: "Kitchen"}] =
             EspexTree.device_config(@devices)[:devices]
  end

  test "device_id reserves 0 for :default and is otherwise stable" do
    assert Platform.device_id(:default) == 0
    assert Platform.device_id(:kitchen) == Platform.device_id(:kitchen)
    assert Platform.device_id(:kitchen) != 0
  end
end
