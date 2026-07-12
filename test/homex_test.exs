defmodule HomexTest do
  use Homex.EntityCase, async: true
  doctest Homex

  defmodule LifecycleSwitch do
    use Homex.Entity.Switch, name: "lifecycle-switch"
  end

  test "add_entity and remove_entity notify the adapters" do
    assert :ok = Homex.add_entity(LifecycleSwitch)
    assert_receive :entities_changed
    assert {:ok, %Homex.Descriptor{kind: :switch}} = Homex.descriptor("lifecycle-switch")

    assert :ok = Homex.remove_entity("lifecycle-switch")
    assert_receive :entities_changed
    assert {:error, :not_found} = Homex.descriptor("lifecycle-switch")
  end

  test "adding an invalid entity returns an error and notifies nothing" do
    assert {:error, :entity_invalid} = Homex.add_entity(Enum)
    refute_receive :entities_changed
  end

  test "removing an unknown entity returns an error" do
    assert {:error, :not_found} = Homex.remove_entity("does-not-exist")
  end
end
