defmodule Homex.Entity.LightTest do
  use Homex.EntityCase, async: true

  alias Homex.Entity.Light

  defmodule TestLight do
    use Homex.Entity.Light, name: "test-light", modes: [:brightness]

    @impl Homex.Entity.Light
    def handle_on(entity) do
      send(:light_test, {:handle_on, entity.changes})
      entity
    end

    @impl Homex.Entity.Light
    def handle_off(entity) do
      send(:light_test, {:handle_off, entity.changes})
      entity
    end

    @impl Homex.Entity.Light
    def handle_brightness(entity, value) do
      send(:light_test, {:handle_brightness, value, entity.changes})
      entity
    end
  end

  defmodule SimpleLight do
    use Homex.Entity.Light, name: "simple-light"
  end

  setup do
    Process.register(self(), :light_test)
    {:ok, entity} = Entity.new(TestLight)
    start_supervised!({Entity, entity})
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

    stop_supervised!({Entity, "test-light"})
    {:ok, entity} = Entity.new(TestLight)
    start_supervised!({Entity, entity})

    Entity.send_command("test-light", %{state: true})
    Entity.send_command("test-light", %{brightness: 50})

    assert Entity.snapshot("test-light") == compound_snapshot
  end

  test "brightness is ignored when the mode is not enabled" do
    {:ok, entity} = SimpleLight.new(name: "onoff-light")
    start_supervised!({Entity, entity})
    assert_receive {:publish_state, _, %{state: false}}
    Entity.send_command("onoff-light", %{brightness: 50})
    refute_receive {:publish_state, _, _}
  end

  describe "setup/1" do
    test "defaults to off with zero brightness when the mode is enabled" do
      {:ok, entity} = SimpleLight.new(name: "fn-light", modes: [:brightness])
      assert Light.setup(entity).changes == %{state: false, brightness: 0}
    end

    test "defaults to off only when brightness is not enabled" do
      {:ok, entity} = SimpleLight.new(name: "fn-light")
      assert Light.setup(entity).changes == %{state: false}
    end
  end

  describe "handle_command/2" do
    test "records state and brightness from a compound command" do
      {:ok, entity} = SimpleLight.new(name: "fn-light", modes: [:brightness])
      entity = Light.handle_command(%{state: true, brightness: 50}, entity)

      assert entity.changes == %{state: true, brightness: 50}
    end

    test "drops brightness when the mode is not enabled" do
      {:ok, entity} = SimpleLight.new(name: "fn-light")
      entity = Light.handle_command(%{state: true, brightness: 50}, entity)

      assert entity.changes == %{state: true}
    end
  end

  describe "set_brightness/2" do
    test "rejects out-of-range values" do
      {:ok, entity} = Light.new(name: "fn-light", modes: [:brightness])

      assert_raise FunctionClauseError, fn -> Light.set_brightness(entity, 101) end
      assert_raise FunctionClauseError, fn -> Light.set_brightness(entity, -1) end
    end
  end

  describe "MQTT publish" do
    alias Homex.Adapter.MQTT

    @desc %Descriptor{kind: :light, name: "test-light", fields: %{state: :state}}
    @topics %{state: "homex/light/id", command: "homex/light/id/set"}

    test "the state is in every message, also when only the brightness changed" do
      values = %{state: true, brightness: 78}

      assert [{"homex/light/id", payload}] =
               MQTT.Light.publish(@desc, @topics, values, %{brightness: 78})

      assert Homex.decode!(payload) == %{"state" => "ON", "brightness" => 199}
    end

    test "an off light reports its brightness too" do
      assert [{_topic, payload}] =
               MQTT.Light.publish(@desc, @topics, %{state: false, brightness: 0}, %{state: false})

      assert Homex.decode!(payload) == %{"state" => "OFF", "brightness" => 0}
    end

    test "no message while the state is unknown" do
      assert [] == MQTT.Light.publish(@desc, @topics, %{brightness: 78}, %{brightness: 78})
    end
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
