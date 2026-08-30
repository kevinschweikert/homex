defmodule Homex.Adapter.ESPHome.Light do
  @moduledoc false

  alias Homex.Descriptor
  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform

  @behaviour Platform

  @impl Platform
  def list_entity(%Descriptor{options: %{modes: []}}) do
    %Proto.ListEntitiesLightResponse{supported_color_modes: [:COLOR_MODE_ON_OFF]}
  end

  def list_entity(%Descriptor{options: options}) do
    %Proto.ListEntitiesLightResponse{
      supported_color_modes: Enum.map(options.modes, &color_mode/1)
    }
  end

  @impl Platform
  def state(%Descriptor{options: options}, %{state: state, brightness: brightness}) do
    %Proto.LightStateResponse{
      state: state,
      brightness: brightness / 100,
      color_mode: options.modes |> List.last() |> color_mode()
    }
  end

  @impl Platform
  def command(%Proto.LightCommandRequest{state: state, brightness: brightness}),
    do: %{state: state, brightness: brightness * 100}

  def command(_request), do: nil

  defp color_mode(nil), do: :COLOR_MODE_ON_OFF
  defp color_mode(:on_off), do: :COLOR_MODE_ON_OFF
  defp color_mode(:brightness), do: :COLOR_MODE_BRIGHTNESS
end
