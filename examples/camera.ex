defmodule Camera do
  @moduledoc """
  A Homex.Entity for a webcam
  """

  use Homex.Entity.Camera, name: "my-camera", image_encoding: "b64", update_interval: 1_000

  def handle_init(entity) do
    r = Xav.Reader.new!("C922 Pro Stream Webcam", device?: true)
    entity |> put_private(:reader, r)
  end

  def handle_timer(entity) do
    r = entity |> get_private(:reader)
    {:ok, %Xav.Frame{} = frame} = Xav.Reader.next_frame(r)

    {:ok, img} =
      Vix.Vips.Image.new_from_binary(frame.data, frame.width, frame.height, 3, :VIPS_FORMAT_UCHAR)

    img = img |> Image.thumbnail!(200)
    binary = img |> Image.write!(:memory, suffix: ".jpg") |> Base.encode64()

    entity
    |> set_image(binary)
    |> set_attributes(%{width: Image.width(img), height: Image.height(img)})
  end
end
