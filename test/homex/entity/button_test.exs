defmodule Homex.Entity.ButtonTest do
  use Homex.EntityCase, async: true

  defmodule TestButton do
    use Homex.Entity.Button, name: "test-button", device_class: "restart"

    def handle_press(entity) do
      send(:button_test, :pressed)
      set_attributes(entity, %{count: 1})
    end
  end

  setup do
    Process.register(self(), :button_test)
    start_supervised!({Entity, Entity.new(TestButton)})
    :ok
  end

  test "descriptor carries kind, options and the event field" do
    assert {:ok,
            %Descriptor{
              kind: :button,
              fields: %{pressed: :event, attrs: :state},
              options: %{device_class: "restart"}
            }} = Homex.descriptor("test-button")
  end

  test "a press command fires handle_press every time" do
    Entity.send_command("test-button", %{pressed: true})
    assert_receive :pressed
    assert_receive {:publish_state, %Descriptor{kind: :button}, %{attrs: %{count: 1}}}

    Entity.send_command("test-button", %{pressed: true})
    assert_receive :pressed
  end

  test "unknown commands are ignored" do
    Entity.send_command("test-button", %{state: true})
    refute_receive :pressed
  end
end
