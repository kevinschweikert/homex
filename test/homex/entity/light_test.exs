defmodule Homex.Entity.LightTest do
  use ExUnit.Case, async: true
  doctest Homex.Entity.Light

  defmodule TestLight do
    use Homex.Entity.Light, name: "test-light"
  end

  describe "behaviour" do
    test "platform" do
      assert TestLight.platform() == "light"
    end

    test "config" do
      assert TestLight.config() == %{
               platform: "light",
               state_topic: "homex/light/test_light",
               command_topic: "homex/light/test_light/set",
               brightness_state_topic: "homex/light/test_light/brightness",
               brightness_command_topic: "homex/light/test_light/brightness/set",
               name: "test_light",
               unique_id: "light_test_light_49938759"
             }
    end
  end
end
