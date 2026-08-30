defmodule HomexTest do
  # neither `{:homex, :entities_changed}` nor `{:homex, :devices_changed}` carries
  # a discriminator, so this module cannot run concurrently with anything else
  # that adds/removes entities or devices.
  use Homex.EntityCase, async: false
  doctest Homex

  defmodule LifecycleSwitch do
    use Homex.Entity.Switch, id: :lifecycle_switch, name: "Lifecycle Switch"
  end

  test "add_entity and remove_entity notify the adapters" do
    assert :ok = Homex.add_entity(LifecycleSwitch)
    assert_receive {:homex, :entities_changed}
    assert {:ok, %Homex.Descriptor{kind: :switch}} = Homex.descriptor(:lifecycle_switch)

    assert :ok = Homex.remove_entity(:lifecycle_switch)
    assert_receive {:homex, :entities_changed}
    assert {:error, :not_found} = Homex.descriptor(:lifecycle_switch)
  end

  test "adding an invalid entity returns an error and notifies nothing" do
    assert {:error, :entity_invalid} = Homex.add_entity(Enum)
    refute_receive {:homex, :entities_changed}
  end

  test "put_device replaces and delete_device removes, notifying the adapters" do
    assert :ok = Homex.put_device(:office, name: "Office")
    assert_receive {:homex, :devices_changed}
    assert %Homex.Device{name: "Office"} = Homex.devices()[:office]

    assert :ok = Homex.put_device(:office, name: "Renamed")
    assert_receive {:homex, :devices_changed}
    assert %Homex.Device{name: "Renamed"} = Homex.devices()[:office]

    assert {:error, %NimbleOptions.ValidationError{}} = Homex.put_device(:office, name: :nope)

    assert :ok = Homex.delete_device(:office)
    assert_receive {:homex, :devices_changed}
    refute Homex.devices()[:office]
  end

  test "removing an unknown entity returns an error" do
    assert {:error, :not_found} = Homex.remove_entity(:does_not_exist)
  end
end
