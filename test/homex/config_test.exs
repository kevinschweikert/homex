defmodule Homex.ConfigTest do
  use ExUnit.Case, async: true

  alias Homex.Config

  describe "new/1" do
    test "device settings override defaults" do
      config = Config.new(device: [name: "Testing"])
      assert config.device.name == "Testing"
    end
  end
end
