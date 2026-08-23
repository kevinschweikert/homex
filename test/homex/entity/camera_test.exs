defmodule Homex.Entity.CameraTest do
  use Homex.EntityCase, async: true

  defmodule TestCamera do
    use Homex.Entity.Camera, name: "test-camera"

    def handle_info({:snap, image}, entity), do: set_image(entity, image)
    def handle_info({:attrs, attrs}, entity), do: set_attributes(entity, attrs)
  end

  setup do
    {:ok, entity} = Entity.new(TestCamera)
    start_supervised!({Entity, entity})
    :ok
  end

  test "descriptor tracks image and attrs as independent state fields" do
    assert {:ok, %Descriptor{kind: :camera, fields: %{image: :state, attrs: :state}}} =
             Homex.descriptor("test-camera")
  end

  test "image and attrs changes each publish to their own topic" do
    Homex.notify("test-camera", {:snap, <<1, 2, 3>>})
    assert_receive {:homex, :state, %Descriptor{kind: :camera}, _, %{image: <<1, 2, 3>>}}

    Homex.notify("test-camera", {:attrs, %{motion: true}})
    assert_receive {:homex, :state, _, _, %{attrs: %{motion: true}}}
  end

  describe "set_image/2 and set_attributes/2" do
    alias Homex.Entity.Camera

    test "record independent changes" do
      {:ok, entity} = Camera.new(name: "fn-camera")
      entity = entity |> Camera.set_image(<<1>>) |> Camera.set_attributes(%{motion: true})

      assert entity.changes == %{image: <<1>>, attrs: %{motion: true}}
    end
  end
end
