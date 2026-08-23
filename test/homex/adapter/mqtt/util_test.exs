defmodule Homex.Adapter.MQTT.UtilTest do
  use ExUnit.Case, async: true

  alias Homex.Adapter.MQTT.Util
  alias Homex.Descriptor

  @prod %Descriptor{device: nil, kind: :sensor, name: "temp", fields: %{state: :state}}
  @dev %Descriptor{device: :dev, kind: :sensor, name: "temp", fields: %{state: :state}}

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
      | options: %{device_class: "temperature"},
        transport: %{mqtt: [retain: false]}
    }

    assert Util.component_identifier("node", @prod) == Util.component_identifier("node", changed)
  end

  test "two entities on one node get different identifiers" do
    other = %{@prod | name: "humidity"}

    refute Util.component_identifier("node", @prod) == Util.component_identifier("node", other)
  end

  test "two names with the same slug get different identifiers" do
    spaced = %{@prod | name: "living room"}
    dashed = %{@prod | name: "living-room"}

    assert Homex.Util.slug(spaced.name) == Homex.Util.slug(dashed.name)

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
