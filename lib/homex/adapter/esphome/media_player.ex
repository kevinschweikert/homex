defmodule Homex.Adapter.ESPHome.MediaPlayer do
  @moduledoc false

  import Bitwise

  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform
  alias Homex.Descriptor

  @behaviour Platform

  # MediaPlayerEntityFeature bits, from esphome's media_player.h. These six are what
  # esphome always reports, and a player that can pause adds the two after them.
  @play_media 1 <<< 9
  @browse_media 1 <<< 17
  @stop 1 <<< 12
  @volume_set 1 <<< 2
  @volume_mute 1 <<< 3
  @media_announce 1 <<< 20
  @pause 1 <<< 0
  @play 1 <<< 14

  @base @play_media ||| @browse_media ||| @stop ||| @volume_set ||| @volume_mute |||
          @media_announce

  @impl Platform
  def list_entity(%Descriptor{options: options}) do
    pause? = options.pause

    # a client below api version 1.11 ignores feature_flags and reads supports_pause,
    # and one from 1.11 reads only feature_flags, so both have to say the same thing
    %Proto.ListEntitiesMediaPlayerResponse{
      feature_flags: if(pause?, do: @base ||| @pause ||| @play, else: @base),
      supports_pause: pause?
    }
  end

  @impl Platform
  def state(%Descriptor{}, %{state: state, volume: volume, muted: muted}) do
    %Proto.MediaPlayerStateResponse{
      state: proto_state(state),
      volume: volume || 0.0,
      muted: muted || false
    }
  end

  @impl Platform
  def command(%Proto.MediaPlayerCommandRequest{} = request) do
    %{}
    |> Map.merge(take_command(request))
    |> Map.merge(take_volume(request))
    |> Map.merge(take_media(request))
  end

  def command(_request), do: nil

  defp take_command(%Proto.MediaPlayerCommandRequest{has_command: true, command: command}),
    do: core_command(command)

  defp take_command(_request), do: %{}

  defp take_volume(%Proto.MediaPlayerCommandRequest{has_volume: true, volume: volume}),
    do: %{volume: volume}

  defp take_volume(_request), do: %{}

  defp take_media(
         %Proto.MediaPlayerCommandRequest{has_media_url: true, media_url: url} = request
       ),
       do: %{media: {url, announcement(request)}}

  defp take_media(_request), do: %{}

  defp announcement(%Proto.MediaPlayerCommandRequest{
         has_announcement: true,
         announcement: announcement
       }),
       do: announcement

  defp announcement(_request), do: false

  # ha speaks the full MediaPlayerCommand enum. the rest of it is playlist work that
  # an entity of this kind does not model, and an unknown command changes nothing.
  defp core_command(:MEDIA_PLAYER_COMMAND_PLAY), do: %{command: :play}
  defp core_command(:MEDIA_PLAYER_COMMAND_PAUSE), do: %{command: :pause}
  defp core_command(:MEDIA_PLAYER_COMMAND_STOP), do: %{command: :stop}
  defp core_command(:MEDIA_PLAYER_COMMAND_MUTE), do: %{command: :mute}
  defp core_command(:MEDIA_PLAYER_COMMAND_UNMUTE), do: %{command: :unmute}
  defp core_command(:MEDIA_PLAYER_COMMAND_TOGGLE), do: %{command: :toggle}
  defp core_command(:MEDIA_PLAYER_COMMAND_VOLUME_UP), do: %{command: :volume_up}
  defp core_command(:MEDIA_PLAYER_COMMAND_VOLUME_DOWN), do: %{command: :volume_down}
  defp core_command(:MEDIA_PLAYER_COMMAND_TURN_ON), do: %{command: :turn_on}
  defp core_command(:MEDIA_PLAYER_COMMAND_TURN_OFF), do: %{command: :turn_off}
  defp core_command(_other), do: %{}

  defp proto_state(:none), do: :MEDIA_PLAYER_STATE_NONE
  defp proto_state(:idle), do: :MEDIA_PLAYER_STATE_IDLE
  defp proto_state(:playing), do: :MEDIA_PLAYER_STATE_PLAYING
  defp proto_state(:paused), do: :MEDIA_PLAYER_STATE_PAUSED
  defp proto_state(:announcing), do: :MEDIA_PLAYER_STATE_ANNOUNCING
  defp proto_state(:off), do: :MEDIA_PLAYER_STATE_OFF
  defp proto_state(:on), do: :MEDIA_PLAYER_STATE_ON
  defp proto_state(_other), do: :MEDIA_PLAYER_STATE_NONE
end
