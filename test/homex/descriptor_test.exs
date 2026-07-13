defmodule Homex.DescriptorTest do
  use ExUnit.Case, async: true

  alias Homex.Descriptor

  @desc %Descriptor{kind: :sensor, name: "temp", fields: %{state: :state}}
  @device %{name: "prod-host", identifiers: ["prod-host"]}

  test "same entity on different devices gets different unique_ids" do
    prod = Descriptor.put_unique_id(@desc, @device)
    dev = Descriptor.put_unique_id(@desc, %{name: "dev-host", identifiers: ["dev-host"]})

    assert prod.unique_id != dev.unique_id
  end

  test "unique_id is stable against non-identity descriptor changes" do
    base = Descriptor.put_unique_id(@desc, @device)

    changed =
      %{@desc | options: %{device_class: "temperature"}, transport: %{mqtt: [retain: false]}}
      |> Descriptor.put_unique_id(@device)

    assert base.unique_id == changed.unique_id
  end
end
