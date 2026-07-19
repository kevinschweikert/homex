defmodule Homex.Entity.DeviceTriggerTest do
  use Homex.EntityCase, async: true

  defmodule TestTrigger do
    use Homex.Entity.DeviceTrigger, name: "test-trigger", payload: "pressed"
  end

  setup do
    {:ok, entity} = Entity.new(TestTrigger)
    start_supervised!({Entity, entity})
    :ok
  end

  test "descriptor marks its field as an event" do
    assert {:ok, %Descriptor{kind: :device_trigger, fields: %{trigger: :event}}} =
             Homex.descriptor("test-trigger")
  end

  test "firing twice in a row publishes both times" do
    Homex.Entity.DeviceTrigger.trigger("test-trigger")
    assert_receive {:publish_state, %Descriptor{kind: :device_trigger}, %{trigger: true}}

    Homex.Entity.DeviceTrigger.trigger("test-trigger")
    assert_receive {:publish_state, _, %{trigger: true}}
  end

  test "runs bare, without a use-based module" do
    {:ok, entity} = Entity.new({Homex.Entity.DeviceTrigger, name: "bare-trigger"})
    start_supervised!({Entity, entity}, id: :bare)

    Homex.Entity.DeviceTrigger.trigger("bare-trigger")
    assert_receive {:publish_state, %Descriptor{kind: :device_trigger}, %{trigger: true}}
  end

  describe "handle_command/2" do
    alias Homex.Entity.DeviceTrigger

    test "records the trigger event" do
      {:ok, entity} = DeviceTrigger.new(name: "fn-trigger")
      assert DeviceTrigger.handle_command(%{trigger: true}, entity).changes == %{trigger: true}
    end

    test "ignores other commands" do
      {:ok, entity} = DeviceTrigger.new(name: "fn-trigger")
      assert DeviceTrigger.handle_command(%{state: true}, entity) == entity
    end
  end
end
