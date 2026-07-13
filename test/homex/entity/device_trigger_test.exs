defmodule Homex.Entity.DeviceTriggerTest do
  use Homex.EntityCase, async: true

  defmodule TestTrigger do
    use Homex.Entity.DeviceTrigger, name: "test-trigger", payload: "pressed"
  end

  setup do
    start_supervised!({Entity, Entity.new(TestTrigger)})
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
end
