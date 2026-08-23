defmodule Homex.EntityTest do
  use Homex.EntityCase, async: true

  defmodule TestSwitch do
    use Homex.Entity.Switch, name: "entity-test-switch"
  end

  defp entity(fields) do
    %Entity{descriptor: %Descriptor{kind: :switch, name: :test, fields: fields}}
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
    test "accepts a bare module with opts baked in at use time" do
      assert {:ok,
              %Entity{
                module: TestSwitch,
                descriptor: %Descriptor{kind: :switch, name: "entity-test-switch"}
              }} = Entity.new(TestSwitch)
    end

    test "accepts a {module, opts} pair overriding baked-in opts" do
      assert {:ok, %Entity{module: TestSwitch, descriptor: %Descriptor{name: "other-name"}}} =
               Entity.new({TestSwitch, name: "other-name"})
    end

    test "accepts a kind module directly, without a use-based module" do
      assert {:ok,
              %Entity{
                module: Homex.Entity.DeviceTrigger,
                descriptor: %Descriptor{name: "plain"}
              }} = Entity.new({Homex.Entity.DeviceTrigger, name: "plain"})
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
               Entity.new({Homex.Entity.Switch, name: "plain"})
    end
  end

  describe "instance names" do
    test "two instances of one handler run side by side with distinct identities" do
      {:ok, default} = Entity.new(TestSwitch)
      {:ok, second} = Entity.new({TestSwitch, name: "second-switch"})

      start_supervised!({Entity, default}, id: :default)
      start_supervised!({Entity, second}, id: :second)

      assert {:ok, %Descriptor{name: "entity-test-switch"}} =
               Homex.descriptor("entity-test-switch")

      assert {:ok, %Descriptor{name: "second-switch"}} = Homex.descriptor("second-switch")

      Entity.send_command("second-switch", %{state: true})
      assert_receive {:publish_state, %Descriptor{name: "second-switch"}, %{state: true}}
    end
  end
end
