defmodule Homex.Entity.CameraTest do
  use Homex.EntityCase, async: true

  defmodule TestCamera do
    use Homex.Entity.Camera, name: "test-camera"

    def handle_info({:snap, image}, entity), do: set_image(entity, image)
    def handle_info({:attrs, attrs}, entity), do: set_attributes(entity, attrs)
  end

  setup do
    start_supervised!({Entity, Entity.new(TestCamera)})
    :ok
  end

  test "descriptor tracks image and attrs as independent state fields" do
    assert {:ok, %Descriptor{kind: :camera, fields: %{image: :state, attrs: :state}}} =
             Homex.descriptor("test-camera")
  end

  test "image and attrs changes each publish to their own topic" do
    Homex.notify("test-camera", {:snap, <<1, 2, 3>>})
    assert_receive {:publish_state, %Descriptor{kind: :camera}, %{image: <<1, 2, 3>>}}

    Homex.notify("test-camera", {:attrs, %{motion: true}})
    assert_receive {:publish_state, _, %{attrs: %{motion: true}}}
  end
end
