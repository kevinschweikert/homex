defmodule Homex.Entity.MediaPlayer do
  use Homex.Entity

  alias Homex.Entity

  @type state() :: :none | :idle | :playing | :paused | :announcing | :off | :on
  @states [:none, :idle, :playing, :paused, :announcing, :off, :on]

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
                 pause: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc:
                     "if the player can pause. A player that can only start and stop sets this to `false`, and Home Assistant then draws no pause control."
                 ],
                 volume_step: [
                   required: false,
                   type: :float,
                   default: 0.05,
                   doc:
                     "how far a volume up or volume down command moves the volume. Home Assistant sends those as commands and not as values, so the entity decides the step."
                 ]
               )
               |> NimbleOptions.new!()

  @moduledoc """
  A media player entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  ## This entity needs the ESPHome adapter

  Home Assistant has no MQTT media player: its MQTT integration serves lights,
  switches, sensors and two dozen other platforms, and a player is not one of them.
  Its ESPHome integration does serve one, so `Homex.Adapter.ESPHome` publishes this
  entity and `Homex.Adapter.MQTT` skips it, in the way that either adapter skips any
  kind it does not know.

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MyPlayer do
    use Homex.Entity.MediaPlayer, id: :my_player, name: "My Player"

    def handle_play(entity) do
      IO.puts("Play")
      set_state(entity, :playing)
    end

    def handle_pause(entity) do
      IO.puts("Pause")
      set_state(entity, :paused)
    end

    def handle_volume(entity, volume) do
      IO.puts("Volume at \#{round(volume * 100)}%")
      entity
    end
  end
  ```

  ## The entity reports, and the callbacks decide

  **A command changes nothing on its own.** `handle_play/1` is called with the entity
  as the command found it, and the state that Home Assistant draws is whatever that
  callback returns. A player that cannot start the track it was told to start
  therefore reports the truth rather than a state it never reached.

  Volume and mute are the exception, because Home Assistant draws a slider that must
  follow the finger of a person. The entity stages both before it calls the callback,
  in the way that `Homex.Entity.Light` stages its brightness.

  ## Value ranges

  The volume is normalized to `0.0..1.0`.
  """

  @doc """
  Gets called when the player receives a play command
  """
  @callback handle_play(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the player receives a pause command
  """
  @callback handle_pause(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the player receives a stop command
  """
  @callback handle_stop(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the player receives a turn on command
  """
  @callback handle_turn_on(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the player receives a turn off command
  """
  @callback handle_turn_off(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the player receives a new volume. Between 0 and 1.

  A volume up or volume down command arrives here as well, moved by `:volume_step`.
  """
  @callback handle_volume(entity :: Entity.t(), volume :: float()) :: entity :: Entity.t()

  @doc """
  Gets called when the player is muted or unmuted
  """
  @callback handle_mute(entity :: Entity.t(), muted :: boolean()) :: entity :: Entity.t()

  @doc """
  Gets called with the address of media to play.

  `announcement` is `true` for media that Home Assistant wants played over whatever
  is on now, such as a spoken notification.
  """
  @callback handle_media(entity :: Entity.t(), url :: String.t(), announcement :: boolean()) ::
              entity :: Entity.t()

  @optional_callbacks handle_play: 1,
                      handle_pause: 1,
                      handle_stop: 1,
                      handle_turn_on: 1,
                      handle_turn_off: 1,
                      handle_volume: 2,
                      handle_mute: 2,
                      handle_media: 3

  defmacro __using__(opts) do
    quote do
      unquote(
        Homex.Entity.__entity__(__MODULE__, opts,
          set_state: 2,
          set_volume: 2,
          set_muted: 2
        )
      )

      def handle_play(entity), do: entity
      def handle_pause(entity), do: entity
      def handle_stop(entity), do: entity
      def handle_turn_on(entity), do: entity
      def handle_turn_off(entity), do: entity
      def handle_volume(entity, _volume), do: entity
      def handle_mute(entity, _muted), do: entity
      def handle_media(entity, _url, _announcement), do: entity

      defoverridable handle_play: 1,
                     handle_pause: 1,
                     handle_stop: 1,
                     handle_turn_on: 1,
                     handle_turn_off: 1,
                     handle_volume: 2,
                     handle_mute: 2,
                     handle_media: 3
    end
  end

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    %Homex.Descriptor{
      kind: :media_player,
      fields: %{state: :state, volume: :state, muted: :state},
      name: opts[:name],
      options: %{pause: opts[:pause], volume_step: opts[:volume_step]},
      transport: %{}
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity) do
    entity
    |> set_state(:idle)
    |> set_volume(1.0)
    |> set_muted(false)
    |> m.handle_init()
  end

  @impl Homex.Entity
  def handle_command(cmd, %{module: m} = entity) do
    steps = steps(cmd, entity, m)

    entity
    |> stage_all(steps)
    |> notify_all(steps)
  end

  # against the entity as the command found it, before anything is staged
  defp steps(cmd, entity, m), do: Enum.flat_map(cmd, &step(&1, entity, m))

  defp stage_all(entity, steps),
    do: Enum.reduce(steps, entity, fn {stage, _notify}, entity -> stage.(entity) end)

  defp notify_all(entity, steps),
    do: Enum.reduce(steps, entity, fn {_stage, notify}, entity -> notify.(entity) end)

  # the transport commands stage nothing: the callback says what state the player
  # reached, and a player that could not start the track must not report playing
  defp step({:command, :play}, _entity, m), do: [{&Function.identity/1, &m.handle_play/1}]
  defp step({:command, :pause}, _entity, m), do: [{&Function.identity/1, &m.handle_pause/1}]
  defp step({:command, :stop}, _entity, m), do: [{&Function.identity/1, &m.handle_stop/1}]
  defp step({:command, :turn_on}, _entity, m), do: [{&Function.identity/1, &m.handle_turn_on/1}]

  defp step({:command, :turn_off}, _entity, m),
    do: [{&Function.identity/1, &m.handle_turn_off/1}]

  # a toggle means the opposite of what the player is doing now, and only the entity
  # knows that
  defp step({:command, :toggle}, entity, m), do: [toggled(entity, m)]

  defp step({:command, :mute}, _entity, m), do: [muting(true, m)]
  defp step({:command, :unmute}, _entity, m), do: [muting(false, m)]

  defp step({:command, :volume_up}, entity, m), do: [stepping(entity, m, 1)]
  defp step({:command, :volume_down}, entity, m), do: [stepping(entity, m, -1)]

  defp step({:volume, value}, _entity, m), do: [volume(value, m)]
  defp step({:muted, value}, _entity, m), do: [muting(value, m)]

  defp step({:media, {url, announcement}}, _entity, m),
    do: [{&Function.identity/1, &m.handle_media(&1, url, announcement)}]

  defp step(_other, _entity, _m), do: []

  defp toggled(entity, m) do
    case current(entity, :state) do
      :playing -> {&Function.identity/1, &m.handle_pause/1}
      _other -> {&Function.identity/1, &m.handle_play/1}
    end
  end

  defp muting(value, m), do: {&set_muted(&1, value), &m.handle_mute(&1, value)}

  defp volume(value, m), do: {&set_volume(&1, value), &m.handle_volume(&1, value)}

  defp stepping(entity, m, direction) do
    step = entity.descriptor.options.volume_step
    moved = (current(entity, :volume) || 0.0) + direction * step

    volume(moved |> max(0.0) |> min(1.0), m)
  end

  defp current(%Entity{values: values, changes: changes}, key),
    do: Map.get(changes, key, Map.get(values, key))

  @doc """
  Sets what the player is doing
  """
  @spec set_state(Entity.t(), state()) :: Entity.t()
  def set_state(%Entity{} = entity, state) when state in @states,
    do: Entity.put_change(entity, :state, state)

  @doc """
  Sets the volume of the player. Must be between 0 and 1
  """
  @spec set_volume(Entity.t(), number()) :: Entity.t()
  def set_volume(%Entity{} = entity, value) when value >= 0 and value <= 1,
    do: Entity.put_change(entity, :volume, value)

  @doc """
  Sets whether the player is muted
  """
  @spec set_muted(Entity.t(), boolean()) :: Entity.t()
  def set_muted(%Entity{} = entity, muted) when is_boolean(muted),
    do: Entity.put_change(entity, :muted, muted)
end
