defmodule Homex.ConfigTest do
  use ExUnit.Case, async: true

  alias Homex.Config

  describe "new/1" do
    test "device settings override defaults" do
      config = Config.new(device: [name: "Testing"])
      assert config.device.name == "Testing"
    end

    test "entities accept bare modules and keyword lists" do
      config = Config.new(entities: [MySwitch, [name: :pod_switch, impl: MySwitch]])
      assert config.entities == [MySwitch, [name: :pod_switch, impl: MySwitch]]
    end
  end
end
