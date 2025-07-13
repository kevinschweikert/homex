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
      assert TestLight.subscriptions() == ["homex/light/#{TestLight.unique_id()}/set"]

      assert TestLightBrightness.subscriptions() == [
               "homex/light/#{TestLightBrightness.unique_id()}/set",
               "homex/light/#{TestLightBrightness.unique_id()}/brightness/set"
             ]
    end

    test "config" do
      assert TestLight.config() == %{
               platform: "light",
               state_topic: "homex/light/#{TestLight.unique_id()}",
               command_topic: "homex/light/#{TestLight.unique_id()}/set",
               name: "test-light",
               unique_id: "#{TestLight.unique_id()}"
             }

      assert TestLightBrightness.config() == %{
               platform: "light",
               state_topic: "homex/light/#{TestLightBrightness.unique_id()}",
               command_topic: "homex/light/#{TestLightBrightness.unique_id()}/set",
               brightness_state_topic:
                 "homex/light/#{TestLightBrightness.unique_id()}/brightness",
               brightness_command_topic:
                 "homex/light/#{TestLightBrightness.unique_id()}/brightness/set",
               name: "test-light-brightness",
               unique_id: "#{TestLightBrightness.unique_id()}"
             }
    end
  end
end
