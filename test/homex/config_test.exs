defmodule Homex.ConfigTest do
  use ExUnit.Case, async: true

  alias Homex.Config

  describe "new/1" do
    test "default device available" do
      config = Config.new(id: "config-test", devices: [default: [name: "Testing"]])
      assert config.devices[:default].name == "Testing"
    end

    test "entities accept bare modules and keyword lists" do
      config =
        Config.new(
          id: "config-test",
          entities: [MySwitch, [name: :pod_switch, impl: MySwitch]]
        )

      assert config.entities == [MySwitch, [name: :pod_switch, impl: MySwitch]]
    end
  end
end
