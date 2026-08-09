defmodule Homex.DescriptorTest do
  use ExUnit.Case, async: true

  alias Homex.Descriptor

  @prod %Descriptor{device: nil, kind: :sensor, name: "temp", fields: %{state: :state}}
  @dev %Descriptor{device: :dev, kind: :sensor, name: "temp", fields: %{state: :state}}

  test "moving an entity between devices keeps its unique_id" do
    prod = Descriptor.put_unique_id(@prod, "node")
    dev = Descriptor.put_unique_id(@dev, "node")

    assert prod.unique_id == dev.unique_id
  end

  test "same entity on different nodes gets different unique_ids" do
    one = Descriptor.put_unique_id(@prod, "node-one")
    two = Descriptor.put_unique_id(@prod, "node-two")

    refute one.unique_id == two.unique_id
  end

  test "unique_id is stable against non-identity descriptor changes" do
    base = Descriptor.put_unique_id(@prod, "node")

    changed =
      %{@prod | options: %{device_class: "temperature"}, transport: %{mqtt: [retain: false]}}
      |> Descriptor.put_unique_id("node")

    assert base.unique_id == changed.unique_id
  end
end
