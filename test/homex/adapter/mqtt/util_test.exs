defmodule Homex.Adapter.MQTT.UtilTest do
  use ExUnit.Case, async: true

  alias Homex.Adapter.MQTT.Util
  alias Homex.Descriptor

  @prod %Descriptor{device: nil, kind: :sensor, id: :temp, name: "Temp", fields: %{state: :state}}
  @dev %Descriptor{device: :dev, kind: :sensor, id: :temp, name: "Temp", fields: %{state: :state}}

  test "moving an entity between devices keeps its identifier" do
    assert Util.component_identifier("node", @prod) == Util.component_identifier("node", @dev)
  end

  test "same entity on different nodes gets different identifiers" do
    refute Util.component_identifier("node-one", @prod) ==
             Util.component_identifier("node-two", @prod)
  end

  test "the identifier is stable against non-identity descriptor changes" do
    changed = %{
      @prod
      | name: "Temperature",
        options: %{device_class: "temperature"},
        transport: %{mqtt: [retain: false]}
    }

    assert Util.component_identifier("node", @prod) == Util.component_identifier("node", changed)
  end

  test "two entities on one node get different identifiers" do
    other = %{@prod | id: :humidity}

    refute Util.component_identifier("node", @prod) == Util.component_identifier("node", other)
  end

  test "two ids with the same slug get different identifiers" do
    spaced = %{@prod | id: :"living room"}
    dashed = %{@prod | id: :"living-room"}

    assert Homex.Util.slug(to_string(spaced.id)) == Homex.Util.slug(to_string(dashed.id))

    refute Util.component_identifier("node", spaced) ==
             Util.component_identifier("node", dashed)
  end

  test "every topic of a component starts with the kind and the identifier" do
    {identifier, topic_builder} = Util.identity("node", @prod)

    assert identifier == Util.component_identifier("node", @prod)
    assert topic_builder.([]) == "homex/sensor/#{identifier}"
    assert topic_builder.(["set"]) == "homex/sensor/#{identifier}/set"
  end
end
