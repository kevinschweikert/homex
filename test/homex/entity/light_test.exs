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

    test "subscriptions" do
      assert TestLight.subscriptions() == ["homex/light/test_light_22353644/set"]
    end

    test "config" do
      assert TestLight.config() == %{
               platform: "light",
               state_topic: "homex/light/test_light_22353644",
               command_topic: "homex/light/test_light_22353644/set",
               name: "test-light",
               unique_id: "test_light_22353644"
             }
             }
    end
  end
end
