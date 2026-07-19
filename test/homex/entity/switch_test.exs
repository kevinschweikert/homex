defmodule Homex.Entity.SwitchTest do
  use Homex.EntityCase, async: true

  alias Homex.Entity.Switch

  defmodule TestSwitch do
    use Homex.Entity.Switch, name: "test-switch"

    @impl Homex.Entity.Switch
    def handle_on(entity) do
      send(:switch_test, {:handle_on, entity.changes})
      entity
    end

    @impl Homex.Entity.Switch
    def handle_off(entity) do
      send(:switch_test, {:handle_off, entity.changes})
      entity
    end
  end

  defmodule SimpleSwitch do
    use Homex.Entity.Switch, name: "simple-switch"
  end

  setup do
    Process.register(self(), :switch_test)
    {:ok, entity} = Entity.new(TestSwitch)
    start_supervised!({Entity, entity})
    assert_receive {:publish_state, _, %{state: false}}
    :ok
  end

  test "descriptor carries the switch options" do
    assert {:ok,
            %Descriptor{
              kind: :switch,
              name: "test-switch",
              fields: %{state: :state}
            }} = Homex.descriptor("test-switch")
  end

  test "a command runs set_* before handle_* and publishes the committed diff" do
    Entity.send_command("test-switch", %{state: true})

    assert_receive {:handle_on, %{state: true}}
    assert_receive {:publish_state, %Descriptor{kind: :switch}, %{state: true}}
    assert Entity.snapshot("test-switch") == %{state: true}
  end

  test "an unchanged state still fires the callback but is not re-published" do
    Entity.send_command("test-switch", %{state: true})
    assert_receive {:publish_state, _, %{state: true}}

    Entity.send_command("test-switch", %{state: true})
    assert_receive {:handle_on, _}
    refute_receive {:publish_state, _, _}
  end

  test "turning off after on publishes both transitions" do
    Entity.send_command("test-switch", %{state: true})
    assert_receive {:publish_state, _, %{state: true}}

    Entity.send_command("test-switch", %{state: false})
    assert_receive {:handle_off, %{state: false}}
    assert_receive {:publish_state, _, %{state: false}}
  end

  test "invalid use options fail at compile time" do
    assert_raise NimbleOptions.ValidationError, fn ->
      defmodule BadSwitch do
        use Homex.Entity.Switch, name: 123
      end
    end
  end

  test "unknown command maps are ignored" do
    Entity.send_command("test-switch", %{bogus: true})
    refute_receive {:publish_state, _, _}
  end

  describe "handle_command/2" do
    test "records the state change and dispatches to the entity module" do
      {:ok, entity} = Entity.new({TestSwitch, name: "fn-switch"})
      entity = Switch.handle_command(%{state: true}, entity)

      assert entity.changes == %{state: true}
      assert_receive {:handle_on, %{state: true}}
    end

    test "records the change even without user callbacks" do
      {:ok, entity} = SimpleSwitch.new(name: "fn-switch")
      assert Switch.handle_command(%{state: false}, entity).changes == %{state: false}
    end

    test "leaves the entity untouched on unknown commands" do
      {:ok, entity} = Switch.new(name: "fn-switch")
      assert Switch.handle_command(%{bogus: true}, entity) == entity
    end
  end

  describe "setup/1" do
    test "defaults the switch to off" do
      {:ok, entity} = SimpleSwitch.new(name: "fn-switch")
      assert Switch.setup(entity).changes == %{state: false}
    end
  end
end
