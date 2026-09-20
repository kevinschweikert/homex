defmodule Homex.Adapter.ESPHome.Light do
  @moduledoc false

  alias Homex.Descriptor
  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform

  @behaviour Platform

  @impl Platform
  def list_entity(%Descriptor{options: options}) do
    %Proto.ListEntitiesLightResponse{
      supported_color_modes: Enum.map(options.modes, &color_mode/1)
    }
  end

  @impl Platform
  def state(%Descriptor{}, %{
        state: state,
        brightness: brightness,
        mode: mode,
        color: color
      }) do
    %Proto.LightStateResponse{state: state, color_mode: color_mode(mode)}
    |> Map.merge(brightness(mode, brightness))
    |> Map.merge(color(color))
  end

  @impl Platform
  def command(%Proto.LightCommandRequest{} = request) do
    %{}
    |> Map.merge(take_state(request))
    |> Map.merge(take_brightness(request))
    |> Map.merge(take_rgb(request))
    |> Map.merge(take_mode(request))
  end

  def command(_request), do: nil

  defp take_state(%Proto.LightCommandRequest{has_state: true, state: state}), do: %{state: state}
  defp take_state(_request), do: %{}

  # esphome dims twice, with a master brightness and a colour-channel level, so the
  # two collapse into the single intensity we keep
  defp take_brightness(
         %Proto.LightCommandRequest{has_brightness: true, brightness: value} = request
       ),
       do: %{brightness: value * commanded_color_brightness(request)}

  defp take_brightness(_request), do: %{}

  defp take_rgb(%Proto.LightCommandRequest{has_rgb: true, red: r, green: g, blue: b}),
    do: %{color: {:rgb, r, g, b}}

  defp take_rgb(_request), do: %{}

  defp commanded_color_brightness(%Proto.LightCommandRequest{
         has_color_brightness: true,
         color_brightness: value
       }),
       do: value

  defp commanded_color_brightness(_request), do: 1.0

  defp take_mode(%Proto.LightCommandRequest{has_color_mode: true, color_mode: color_mode}),
    do: core_mode(color_mode)

  defp take_mode(_request), do: %{}

  # ha speaks the full ColorMode enum, of which we implement three
  defp core_mode(:COLOR_MODE_ON_OFF), do: %{mode: :on_off}
  defp core_mode(:COLOR_MODE_BRIGHTNESS), do: %{mode: :brightness}
  defp core_mode(:COLOR_MODE_RGB), do: %{mode: :rgb}
  defp core_mode(_other), do: %{}

  defp color_mode(nil), do: :COLOR_MODE_ON_OFF
  defp color_mode(:on_off), do: :COLOR_MODE_ON_OFF
  defp color_mode(:brightness), do: :COLOR_MODE_BRIGHTNESS
  defp color_mode(:rgb), do: :COLOR_MODE_RGB

  defp brightness(mode, value) when mode in [nil, :on_off] or is_nil(value), do: %{}
  defp brightness(_mode, value), do: %{brightness: value}

  # the stored colour is already the hue at full intensity, so the colour-channel
  # level is always full and the dimming is reported as brightness alone
  defp color({:rgb, r, g, b}), do: %{color_brightness: 1.0, red: r, green: g, blue: b}
  defp color(_), do: %{}
end
