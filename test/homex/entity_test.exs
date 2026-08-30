defmodule Homex.EntityTest do
  use Homex.EntityCase, async: true

  defmodule TestSwitch do
    use Homex.Entity.Switch, id: :entity_test_switch, name: "Entity Test Switch"
  end

  defp entity(fields) do
    %Entity{descriptor: %Descriptor{kind: :switch, id: :test, fields: fields}}
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

      assert_receive {:homex, :state, %Descriptor{kind: :switch}, _, %{state: true}}
      assert entity.values == %{state: true}
      assert entity.changes == %{}
    end

    test "does not publish unchanged values" do
      entity =
        entity(%{state: :state})
        |> Entity.put_change(:state, true)
        |> Entity.execute_change()

      assert_receive {:homex, :state, _, _, %{state: true}}

      entity |> Entity.put_change(:state, true) |> Entity.execute_change()

      refute_receive {:homex, :state, %Descriptor{id: :test}, _, _}
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
    test "accepts a bare module with opts baked in at use time" do
      assert {:ok,
              %Entity{
                module: TestSwitch,
                descriptor: %Descriptor{kind: :switch, id: :entity_test_switch}
              }} = Entity.new(TestSwitch)
    end

    test "accepts a {module, opts} pair overriding baked-in opts" do
      assert {:ok, %Entity{module: TestSwitch, descriptor: %Descriptor{id: :other_switch}}} =
               Entity.new({TestSwitch, id: :other_switch, name: "Other Switch"})
    end

    test "accepts a kind module directly, without a use-based module" do
      assert {:ok,
              %Entity{
                module: Homex.Entity.DeviceTrigger,
                descriptor: %Descriptor{id: :plain}
              }} = Entity.new({Homex.Entity.DeviceTrigger, id: :plain, name: "Plain"})
    end

    test "returns an error tuple on invalid options" do
      assert {:error, %NimbleOptions.ValidationError{}} =
               Entity.new({Homex.Entity.DeviceTrigger, []})
    end

    test "returns an error tuple for a module that is no entity" do
      assert {:error, :entity_invalid} = Entity.new(Enum)
    end

    test "rejects a plain kind module that must be used" do
      assert {:error, :entity_not_runnable} =
               Entity.new({Homex.Entity.Switch, id: :plain, name: "Plain"})
    end
  end

  describe "instance names" do
    test "two instances of one handler run side by side with distinct identities" do
      {:ok, default} = Entity.new(TestSwitch)
      {:ok, second} = Entity.new({TestSwitch, id: :second_switch, name: "Second Switch"})

      start_supervised!({Entity, default}, id: :default)
      start_supervised!({Entity, second}, id: :second)

      assert {:ok, %Descriptor{id: :entity_test_switch}} =
               Homex.descriptor(:entity_test_switch)

      assert {:ok, %Descriptor{id: :second_switch}} = Homex.descriptor(:second_switch)

      Entity.send_command(:second_switch, %{state: true})
      assert_receive {:homex, :state, %Descriptor{id: :second_switch}, _, %{state: true}}
    end
  end
end
