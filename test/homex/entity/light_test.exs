defmodule Homex.Entity.LightTest do
  use Homex.EntityCase, async: true

  defmodule TestLight do
    use Homex.Entity.Light, name: "test-light", modes: [:brightness]

    def handle_on(entity) do
      send(:light_test, {:handle_on, entity.changes})
      entity
    end

    def handle_off(entity) do
      send(:light_test, {:handle_off, entity.changes})
      entity
    end

    def handle_brightness(entity, value) do
      send(:light_test, {:handle_brightness, value, entity.changes})
      entity
    end
  end

  defmodule OnOffLight do
    use Homex.Entity.Light, name: "onoff-light"
  end

  setup do
    Process.register(self(), :light_test)
    start_supervised!({Entity, Entity.new(TestLight)})
    assert_receive {:publish_state, _, %{state: false, brightness: 0}}
    :ok
  end

  test "descriptor includes brightness when the mode is enabled" do
    assert {:ok, %Descriptor{kind: :light, fields: %{state: :state, brightness: :state}}} =
             Homex.descriptor("test-light")
  end

  test "a compound command runs all set_* before any handle_*, in field order" do
    Entity.send_command("test-light", %{state: true, brightness: 50})

    assert_receive {:handle_on, %{state: true, brightness: 50}}
    assert_receive {:handle_brightness, 50, %{}}
    assert_receive {:publish_state, _, %{state: true, brightness: 50}}
  end

  test "a compound command is equivalent to the same commands sent sequentially" do
    Entity.send_command("test-light", %{state: true, brightness: 50})
    assert_receive {:publish_state, _, %{state: true, brightness: 50}}
    compound_snapshot = Entity.snapshot("test-light")

    stop_supervised!({Entity, TestLight})
    start_supervised!({Entity, Entity.new(TestLight)})

    Entity.send_command("test-light", %{state: true})
    Entity.send_command("test-light", %{brightness: 50})

    assert Entity.snapshot("test-light") == compound_snapshot
  end

  test "brightness is ignored when the mode is not enabled" do
    start_supervised!({Entity, Entity.new(OnOffLight)})
    assert_receive {:publish_state, _, %{state: false}}
    Entity.send_command("onoff-light", %{brightness: 50})
    refute_receive {:publish_state, _, _}
  end

  describe "MQTT normalize" do
    alias Homex.Adapter.MQTT

    test "clamps out-of-range brightness" do
      assert %{brightness: 100.0} = MQTT.Light.normalize(~s({"brightness": 300}))
      assert %{brightness: +0.0} = MQTT.Light.normalize(~s({"brightness": -5}))
    end

    test "drops invalid fields instead of passing them through" do
      assert %{state: true} == MQTT.Light.normalize(~s({"state": "ON", "brightness": "high"}))
      assert %{} == MQTT.Light.normalize(~s({"state": "banana"}))
      assert nil == MQTT.Light.normalize("not json")
    end
  end
end
