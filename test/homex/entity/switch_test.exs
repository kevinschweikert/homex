defmodule Homex.Entity.SwitchTest do
  use Homex.EntityCase, async: true

  alias Homex.Entity.Switch

  defmodule TestSwitch do
    use Homex.Entity.Switch, id: :test_switch, name: "Test Switch"

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
    use Homex.Entity.Switch, id: :simple_switch, name: "Simple Switch"
  end

  setup do
    Process.register(self(), :switch_test)
    {:ok, entity} = Entity.new(TestSwitch)
    start_supervised!({Entity, entity})
    assert_receive {:homex, :state, _, _, %{state: false}}
    :ok
  end

  test "descriptor carries the switch options" do
    assert {:ok,
            %Descriptor{
              kind: :switch,
              id: :test_switch,
              name: "Test Switch",
              fields: %{state: :state}
            }} = Homex.descriptor(:test_switch)
  end

  test "a command runs set_* before handle_* and publishes the committed diff" do
    Entity.send_command(:test_switch, %{state: true})

    assert_receive {:handle_on, %{state: true}}
    assert_receive {:homex, :state, %Descriptor{kind: :switch}, _, %{state: true}}
    assert Entity.snapshot(:test_switch) == %{state: true}
  end

  test "an unchanged state still fires the callback but is not re-published" do
    Entity.send_command(:test_switch, %{state: true})
    assert_receive {:homex, :state, _, _, %{state: true}}

    Entity.send_command(:test_switch, %{state: true})
    assert_receive {:handle_on, _}
    refute_receive {:homex, :state, %Descriptor{id: :test_switch}, _, _}
  end

  test "turning off after on publishes both transitions" do
    Entity.send_command(:test_switch, %{state: true})
    assert_receive {:homex, :state, _, _, %{state: true}}

    Entity.send_command(:test_switch, %{state: false})
    assert_receive {:handle_off, %{state: false}}
    assert_receive {:homex, :state, _, _, %{state: false}}
  end

  test "unknown command maps are ignored" do
    Entity.send_command(:test_switch, %{bogus: true})
    refute_receive {:homex, :state, %Descriptor{id: :test_switch}, _, _}
  end

  describe "handle_command/2" do
    test "records the state change and dispatches to the entity module" do
      {:ok, entity} = Entity.new({TestSwitch, id: :fn_switch, name: "Fn Switch"})
      entity = Switch.handle_command(%{state: true}, entity)

      assert entity.changes == %{state: true}
      assert_receive {:handle_on, %{state: true}}
    end

    test "records the change even without user callbacks" do
      {:ok, entity} = SimpleSwitch.new(id: :fn_switch, name: "Fn Switch")
      assert Switch.handle_command(%{state: false}, entity).changes == %{state: false}
    end

    test "leaves the entity untouched on unknown commands" do
      {:ok, entity} = Switch.new(id: :fn_switch, name: "Fn Switch")
      assert Switch.handle_command(%{bogus: true}, entity) == entity
    end
  end

  describe "setup/1" do
    test "defaults the switch to off" do
      {:ok, entity} = SimpleSwitch.new(id: :fn_switch, name: "Fn Switch")
      assert Switch.setup(entity).changes == %{state: false}
    end
  end
end
