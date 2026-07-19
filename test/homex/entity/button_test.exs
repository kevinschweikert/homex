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
    {:ok, entity} = Entity.new(TestButton)
    start_supervised!({Entity, entity})
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

  describe "handle_command/2" do
    alias Homex.Entity.Button

    defmodule Recorder do
      use Homex.Entity.Button, name: "fn-button"

      @impl Homex.Entity.Button
      def handle_press(entity), do: Entity.put_private(entity, :pressed?, true)
    end

    defmodule SimpleButton do
      use Homex.Entity.Button, name: "simple-button"
    end

    test "dispatches a press to the entity module" do
      {:ok, entity} = Entity.new(Recorder)
      entity = Button.handle_command(%{pressed: true}, entity)

      assert Entity.get_private(entity, :pressed?)
    end

    test "leaves the entity untouched without user callbacks" do
      {:ok, entity} = SimpleButton.new(name: "fn-button")
      assert Button.handle_command(%{pressed: true}, entity) == entity
    end
  end
end
