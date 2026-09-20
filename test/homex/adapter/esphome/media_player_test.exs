defmodule Homex.Adapter.ESPHome.MediaPlayerTest do
  use ExUnit.Case, async: true

  import Bitwise

  alias Espex.Proto
  alias Homex.Adapter.ESPHome.MediaPlayer
  alias Homex.Descriptor

  defp descriptor(options \\ %{pause: true, volume_step: 0.05}) do
    %Descriptor{
      kind: :media_player,
      id: :player,
      name: "Player",
      device: :default,
      fields: %{state: :state, volume: :state, muted: :state},
      options: options,
      transport: %{}
    }
  end

  describe "the advertisement" do
    # a client below api version 1.11 reads supports_pause and ignores the flags, and
    # one from 1.11 reads only the flags, so a disagreement between the two means the
    # entity offers different controls depending on the version of the client
    test "the flags and supports_pause say the same thing" do
      assert %Proto.ListEntitiesMediaPlayerResponse{feature_flags: flags, supports_pause: true} =
               MediaPlayer.list_entity(descriptor())

      assert (flags &&& 1 <<< 0) != 0

      assert %Proto.ListEntitiesMediaPlayerResponse{feature_flags: flags, supports_pause: false} =
               MediaPlayer.list_entity(descriptor(%{pause: false, volume_step: 0.05}))

      assert (flags &&& 1 <<< 0) == 0
    end

    test "every player offers the six that esphome always reports" do
      %Proto.ListEntitiesMediaPlayerResponse{feature_flags: flags} =
        MediaPlayer.list_entity(descriptor(%{pause: false, volume_step: 0.05}))

      for bit <- [9, 17, 12, 2, 3, 20], do: assert((flags &&& 1 <<< bit) != 0)
    end
  end

  describe "the state" do
    test "each state of the entity has one of the protocol" do
      states = [
        {:none, :MEDIA_PLAYER_STATE_NONE},
        {:idle, :MEDIA_PLAYER_STATE_IDLE},
        {:playing, :MEDIA_PLAYER_STATE_PLAYING},
        {:paused, :MEDIA_PLAYER_STATE_PAUSED},
        {:announcing, :MEDIA_PLAYER_STATE_ANNOUNCING},
        {:off, :MEDIA_PLAYER_STATE_OFF},
        {:on, :MEDIA_PLAYER_STATE_ON}
      ]

      for {ours, theirs} <- states do
        values = %{state: ours, volume: 0.5, muted: false}

        assert %Proto.MediaPlayerStateResponse{state: ^theirs} =
                 MediaPlayer.state(descriptor(), values)
      end
    end

    # an entity reports before its first values arrive, and a frame of nil is one that
    # the client cannot read
    test "a value that is not set yet reports a number and a boolean" do
      values = %{state: :idle, volume: nil, muted: nil}

      assert %Proto.MediaPlayerStateResponse{volume: +0.0, muted: false} =
               MediaPlayer.state(descriptor(), values)
    end
  end

  describe "a command" do
    test "each command of the protocol has one of the entity" do
      commands = [
        {:MEDIA_PLAYER_COMMAND_PLAY, :play},
        {:MEDIA_PLAYER_COMMAND_PAUSE, :pause},
        {:MEDIA_PLAYER_COMMAND_STOP, :stop},
        {:MEDIA_PLAYER_COMMAND_MUTE, :mute},
        {:MEDIA_PLAYER_COMMAND_UNMUTE, :unmute},
        {:MEDIA_PLAYER_COMMAND_TOGGLE, :toggle},
        {:MEDIA_PLAYER_COMMAND_VOLUME_UP, :volume_up},
        {:MEDIA_PLAYER_COMMAND_VOLUME_DOWN, :volume_down},
        {:MEDIA_PLAYER_COMMAND_TURN_ON, :turn_on},
        {:MEDIA_PLAYER_COMMAND_TURN_OFF, :turn_off}
      ]

      for {theirs, ours} <- commands do
        request = %Proto.MediaPlayerCommandRequest{has_command: true, command: theirs}

        assert MediaPlayer.command(request) == %{command: ours}
      end
    end

    # the rest of the enum is playlist work that this kind does not model
    test "a command that this kind does not model changes nothing" do
      request = %Proto.MediaPlayerCommandRequest{
        has_command: true,
        command: :MEDIA_PLAYER_COMMAND_CLEAR_PLAYLIST
      }

      assert MediaPlayer.command(request) == %{}
    end

    # the has_* flags are what say which fields of the request mean anything
    test "a field with no has_ flag is not read" do
      request = %Proto.MediaPlayerCommandRequest{volume: 0.9, media_url: "http://example.test/x"}

      assert MediaPlayer.command(request) == %{}
    end

    test "a volume arrives with its flag" do
      request = %Proto.MediaPlayerCommandRequest{has_volume: true, volume: 0.9}

      assert MediaPlayer.command(request) == %{volume: 0.9}
    end

    test "media arrives with the address, and announcement defaults to false" do
      request = %Proto.MediaPlayerCommandRequest{
        has_media_url: true,
        media_url: "http://example.test/one.mp3"
      }

      assert MediaPlayer.command(request) == %{media: {"http://example.test/one.mp3", false}}
    end

    test "an announcement says so" do
      request = %Proto.MediaPlayerCommandRequest{
        has_media_url: true,
        media_url: "http://example.test/one.mp3",
        has_announcement: true,
        announcement: true
      }

      assert MediaPlayer.command(request) == %{media: {"http://example.test/one.mp3", true}}
    end

    test "a request of another kind is not ours" do
      assert MediaPlayer.command(%Proto.LightCommandRequest{}) == nil
    end
  end
end
