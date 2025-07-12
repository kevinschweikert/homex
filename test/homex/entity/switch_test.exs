defmodule Homex.Entity.SwitchTest do
  use ExUnit.Case, async: true
  doctest Homex.Entity.Switch

  defmodule TestSwitch do
    use Homex.Entity.Switch, name: "test-switch"
  end

  describe "behaviour" do
    test "platform" do
      assert TestSwitch.platform() == "switch"
    end

    test "config" do
      assert TestSwitch.config() == %{
               platform: "switch",
               state_topic: "homex/switch/test_switch_67474687",
               command_topic: "homex/switch/test_switch_67474687/set",
               name: "test-switch",
               unique_id: "test_switch_67474687"
             }
    end
  end
end
