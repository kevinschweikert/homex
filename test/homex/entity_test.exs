defmodule Homex.EntityTest do
  use Homex.EntityCase, async: true

  defmodule TestSwitch do
    use Homex.Entity.Switch, name: "entity-test-switch"
  end

  defp entity(fields) do
    %Entity{name: :test, descriptor: %Descriptor{kind: :switch, fields: fields}}
  end

  describe "put_change/3" do
    test "records changes for known fields" do
      entity = entity(%{state: :state}) |> Entity.put_change(:state, true)

      assert %{state: true} = entity.changes
    end

    test "ignores unknown fields" do
      entity = entity(%{state: :state}) |> Entity.put_change(:bogus, true)

      assert entity.changes == %{}
    end
  end

  describe "execute_change/1" do
    test "publishes the diff to all adapters and commits the values" do
      entity =
        entity(%{state: :state})
        |> Entity.put_change(:state, true)
        |> Entity.execute_change()

      assert_receive {:publish_state, %Descriptor{kind: :switch}, %{state: true}}
      assert entity.values == %{state: true}
      assert entity.changes == %{}
    end

    test "does not publish unchanged values" do
      entity =
        entity(%{state: :state})
        |> Entity.put_change(:state, true)
        |> Entity.execute_change()

      assert_receive {:publish_state, _, %{state: true}}

      entity |> Entity.put_change(:state, true) |> Entity.execute_change()

      refute_receive {:publish_state, _, _}
    end

    test "existing values stay untouched" do
      entity =
        %{entity(%{state: :state, other: :state}) | values: %{state: nil, other: :foo}}
        |> Entity.put_change(:state, true)
        |> Entity.execute_change()

      assert entity.values == %{state: true, other: :foo}
    end
  end

  describe "new/1" do
    test "accepts a bare module, defaulting name and impl to it" do
      assert %Entity{name: TestSwitch, impl: TestSwitch} = Entity.new(TestSwitch)
    end

    test "accepts a keyword list with name and impl" do
      assert %Entity{name: :my_switch, impl: TestSwitch} =
               Entity.new(name: :my_switch, impl: TestSwitch)
    end

    test "returns nil for invalid input" do
      assert Entity.new(name: :missing_impl) == nil
      assert Entity.new(%{}) == nil
    end
  end

  describe "instance names" do
    test "two instances of one impl run side by side with distinct identities" do
      start_supervised!({Entity, Entity.new(TestSwitch)}, id: :default)

      start_supervised!({Entity, Entity.new(name: "second-switch", impl: TestSwitch)},
        id: :second
      )

      assert {:ok, %Descriptor{name: "entity-test-switch", unique_id: default_id}} =
               Homex.descriptor("entity-test-switch")

      assert {:ok, %Descriptor{name: "second-switch", unique_id: second_id}} =
               Homex.descriptor("second-switch")

      assert default_id != second_id

      Entity.send_command("second-switch", %{state: true})
      assert_receive {:publish_state, %Descriptor{name: "second-switch"}, %{state: true}}
    end
  end

  describe "valid?/1" do
    test "accepts bare modules implementing the behaviour" do
      assert Entity.valid?(TestSwitch)
      refute Entity.valid?(Enum)
    end
  end
end
