defmodule Homex.Entity.SwitchTest do
  use Homex.EntityCase, async: true

  defmodule TestSwitch do
    use Homex.Entity.Switch, name: "test-switch"

    def handle_on(entity) do
      send(:switch_test, {:handle_on, entity.changes})
      entity
    end

    def handle_off(entity) do
      send(:switch_test, {:handle_off, entity.changes})
      entity
    end
  end

  setup do
    Process.register(self(), :switch_test)
    start_supervised!({Entity, Entity.new(TestSwitch)})
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

    Entity.send_command(TestSwitch, %{state: true})
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

  test "unknown command maps are ignored" do
    Entity.send_command("test-switch", %{bogus: true})
    refute_receive {:publish_state, _, _}
  end
end
