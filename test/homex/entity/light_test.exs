defmodule Homex.Entity.LightTest do
  use ExUnit.Case, async: true
  doctest Homex.Entity.Light

  defmodule TestLight do
    use Homex.Entity.Light, name: "test-light"
  end

  defmodule TestLightBrightness do
    use Homex.Entity.Light, name: "test-light-brightness", modes: [:brightness]
  end

  describe "behaviour" do
    test "platform" do
      assert TestLight.platform() == "light"
    end

    test "subscriptions" do
      assert TestLight.subscriptions() == ["homex/light/test_light_22353644/set"]

      assert TestLightBrightness.subscriptions() == [
               "homex/light/test_light_brightness_103627608/set",
               "homex/light/test_light_brightness_103627608/brightness/set"
             ]
    end

    test "config" do
      assert TestLight.config() == %{
               platform: "light",
               state_topic: "homex/light/test_light_22353644",
               command_topic: "homex/light/test_light_22353644/set",
               name: "test-light",
               unique_id: "test_light_22353644"
             }

      assert TestLightBrightness.config() == %{
               platform: "light",
               state_topic: "homex/light/test_light_brightness_10362760",
               command_topic: "homex/light/test_light_brightness_103627608/set",
               brightness_state_topic: "homex/light/test_light_brightness_103627608/brightness",
               brightness_command_topic:
                 "homex/light/test_light_brightness_103627608/brightness/set",
               name: "test-light-brightness",
               unique_id: "test_light_brightness_103627608"
             }
    end
  end
end
