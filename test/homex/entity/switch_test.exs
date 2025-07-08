defmodule Homex.Entity.SwitchTest do
  use ExUnit.Case, async: true
  doctest Homex.Entity.Switch

  defmodule TestSwitch do
    use Homex.Entity.Switch, name: "test-switch"
  end

  describe "behaviour" do
    test "state topic" do
      assert TestSwitch.state_topic() == "homex/switch/test_switch"
    end

    test "command topic" do
      assert TestSwitch.command_topic() == "homex/switch/test_switch/set"
    end

    test "config" do
      assert TestSwitch.config() == %{
               platform: "switch",
               state_topic: "homex/switch/test_switch",
               command_topic: "homex/switch/test_switch/set",
               name: "test_switch",
               unique_id: "switch_test_switch_99193167"
             }
    end
  end
end
