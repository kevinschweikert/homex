defmodule Homex.Entity.MediaPlayerTest do
  use Homex.EntityCase, async: true

  alias Homex.Entity.MediaPlayer

  defmodule TestPlayer do
    use Homex.Entity.MediaPlayer, id: :test_player, name: "Test Player", volume_step: 0.1

    @impl Homex.Entity.MediaPlayer
    def handle_play(entity) do
      send(:media_player_test, {:handle_play, entity.changes})
      MediaPlayer.set_state(entity, :playing)
    end

    @impl Homex.Entity.MediaPlayer
    def handle_pause(entity) do
      send(:media_player_test, {:handle_pause, entity.changes})
      MediaPlayer.set_state(entity, :paused)
    end

    @impl Homex.Entity.MediaPlayer
    def handle_stop(entity) do
      send(:media_player_test, :handle_stop)
      MediaPlayer.set_state(entity, :idle)
    end

    @impl Homex.Entity.MediaPlayer
    def handle_volume(entity, volume) do
      send(:media_player_test, {:handle_volume, volume, entity.changes})
      entity
    end

    @impl Homex.Entity.MediaPlayer
    def handle_mute(entity, muted) do
      send(:media_player_test, {:handle_mute, muted, entity.changes})
      entity
    end

    @impl Homex.Entity.MediaPlayer
    def handle_media(entity, url, announcement) do
      send(:media_player_test, {:handle_media, url, announcement})
      entity
    end
  end

  defmodule SilentPlayer do
    use Homex.Entity.MediaPlayer, id: :silent_player, name: "Silent Player", pause: false
  end

  setup do
    Process.register(self(), :media_player_test)
    {:ok, entity} = Entity.new(TestPlayer)
    start_supervised!({Entity, entity})
    assert_receive {:homex, :state, _, _, %{state: :idle, volume: 1.0, muted: false}}
    :ok
  end

  test "the descriptor carries the three values that a player reports" do
    assert {:ok,
            %Descriptor{
              kind: :media_player,
              fields: %{state: :state, volume: :state, muted: :state}
            }} = Homex.descriptor(:test_player)
  end

  # a player that cannot start the track it was told to start must not report
  # playing, so the callback and not the command decides the state
  test "a transport command stages nothing, and the callback says what happened" do
    Entity.send_command(:test_player, %{command: :play})

    assert_receive {:handle_play, %{}}
    assert_receive {:homex, :state, _, _, %{state: :playing}}
  end

  test "a pause command reaches the callback" do
    Entity.send_command(:test_player, %{command: :pause})

    assert_receive {:handle_pause, %{}}
    assert_receive {:homex, :state, _, _, %{state: :paused}}
  end

  test "a stop command reaches the callback" do
    Entity.send_command(:test_player, %{command: :stop})

    assert_receive :handle_stop
  end

  # ha draws a slider that must follow the finger of a person, so the volume is
  # staged before the callback runs, the way a light stages its brightness
  test "a volume command is staged before the callback" do
    Entity.send_command(:test_player, %{volume: 0.4})

    assert_receive {:handle_volume, 0.4, %{volume: 0.4}}
    assert_receive {:homex, :state, _, _, %{volume: 0.4}}
  end

  test "a mute command is staged before the callback" do
    Entity.send_command(:test_player, %{command: :mute})

    assert_receive {:handle_mute, true, %{muted: true}}
    assert_receive {:homex, :state, _, _, %{muted: true}}

    Entity.send_command(:test_player, %{command: :unmute})

    assert_receive {:handle_mute, false, %{muted: false}}
  end

  # ha sends these as commands and not as values, so the entity owns the step
  test "volume up and volume down move by the step that the entity names" do
    Entity.send_command(:test_player, %{volume: 0.5})
    assert_receive {:handle_volume, 0.5, _changes}

    Entity.send_command(:test_player, %{command: :volume_up})
    assert_receive {:handle_volume, volume, _changes}
    assert_in_delta volume, 0.6, 0.0001

    Entity.send_command(:test_player, %{command: :volume_down})
    assert_receive {:handle_volume, volume, _changes}
    assert_in_delta volume, 0.5, 0.0001
  end

  test "the volume stops at each end rather than leave the range" do
    Entity.send_command(:test_player, %{volume: 0.0})
    assert_receive {:handle_volume, +0.0, _changes}

    Entity.send_command(:test_player, %{command: :volume_down})
    assert_receive {:handle_volume, +0.0, _changes}

    Entity.send_command(:test_player, %{volume: 1.0})
    assert_receive {:handle_volume, 1.0, _changes}

    Entity.send_command(:test_player, %{command: :volume_up})
    assert_receive {:handle_volume, 1.0, _changes}
  end

  # only the entity knows what the player is doing, so the toggle resolves here
  test "a toggle plays a player that is not playing, and pauses one that is" do
    Entity.send_command(:test_player, %{command: :toggle})
    assert_receive {:handle_play, %{}}
    assert_receive {:homex, :state, _, _, %{state: :playing}}

    Entity.send_command(:test_player, %{command: :toggle})
    assert_receive {:handle_pause, %{}}
    assert_receive {:homex, :state, _, _, %{state: :paused}}
  end

  test "media arrives with the address and whether it is an announcement" do
    Entity.send_command(:test_player, %{media: {"http://example.test/one.mp3", true}})

    assert_receive {:handle_media, "http://example.test/one.mp3", true}
  end

  test "a player that names no callbacks takes every command and changes nothing" do
    {:ok, entity} = SilentPlayer.new(id: :quiet_player, name: "Quiet Player")
    start_supervised!({Entity, entity})

    Entity.send_command(:quiet_player, %{command: :play})

    assert %{state: :idle} = Entity.snapshot(:quiet_player)
  end

  test "a player that cannot pause says so in its descriptor" do
    {:ok, entity} = SilentPlayer.new(id: :no_pause_player, name: "No Pause Player")
    start_supervised!({Entity, entity})

    assert {:ok, %Descriptor{options: %{pause: false}}} = Homex.descriptor(:no_pause_player)
  end
end
