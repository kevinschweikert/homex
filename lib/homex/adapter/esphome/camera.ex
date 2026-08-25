defmodule Homex.Adapter.ESPHome.Camera do
  @moduledoc false

  alias Homex.Descriptor
  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform

  @behaviour Platform

  @impl Platform
  def list_entity(%Descriptor{}), do: %Proto.ListEntitiesCameraResponse{}

  @impl Platform
  def state(%Descriptor{options: options}, %{image: image}) do
    data = if options[:image_encoding] == :b64, do: Base.decode64!(image), else: image
    %Proto.CameraImageResponse{data: data, done: true}
  end

  @impl Platform
  def command(%Proto.CameraImageRequest{}), do: %{capture: true}
  def command(_request), do: nil
end
