defmodule Homex.Entity.Light do
  @implemented_modes [:brightness]
  @opts_schema [
                 name: [required: true, type: :string, doc: "the name of the entity"],
                 update_interval: [
                   required: false,
                   type: {:or, [:atom, :integer]},
                   default: :never,
                   doc:
                     "the interval in milliseconds in which `handle_timer/1` get's called. Can also be `:never` to disable the timer callback"
                 ],
                 modes: [
                   required: false,
                   default: [],
                   type: {:custom, __MODULE__, :modes, []},
                   doc:
                     "a list of supported light modes. Available: [#{@implemented_modes |> Enum.map(fn mode -> "`#{mode}`" end) |> Enum.join(", ")}]"
                 ],
                 retain: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "if the last state should be retained"
                 ]
               ]
               |> NimbleOptions.new!()

  @moduledoc """
  A light entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  https://www.home-assistant.io/integrations/light.mqtt/

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Overridable Functions

  The following functions can be overridden in your entity:

  * `handle_init/1` - From `Homex.Entity`
  * `handle_timer/1` - From `Homex.Entity`
  * `handle_on/1` - From `Homex.Entity.Light`
  * `handle_off/1` - From `Homex.Entity.Light`
  * `handle_brightness/1` - From `Homex.Entity.Light`

  ### Default Implementations

  All overridable functions have safe default implementations that return the entity unchanged.
  You only need to override the functions you want to customize.

  ## Example

  ```elixir
  defmodule MyLight do
    use Homex.Entity.Light, name: "my-light", modes: [:brightness]

    def handle_brightness(entity, brightness) do
      IO.puts("Light set to \#{brightness}%")
      entity
    end
  end
  ```
  """

  def modes(mode) when mode in @implemented_modes, do: {:ok, [mode]}
  def modes(mode) when is_atom(mode), do: {:error, :not_implemented}

  def modes(modes) when is_list(modes) do
    if Enum.all?(modes, fn mode -> mode in @implemented_modes end) do
      {:ok, modes}
    else
      not_implemented = Enum.reject(modes, fn mode -> mode in @implemented_modes end)
      {:error, "Not implemented modes #{Enum.join(not_implemented, ", ")} found"}
    end
  end

  alias Homex.Entity

  @doc """
  Sets the light state to on
  """
  @callback set_on(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Sets the light state to off
  """
  @callback set_off(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Sets the lights brightness to the specified value. Must be between 0 and 100
  """
  @callback set_brightness(entity :: Entity.t(), brightness :: float()) :: entity :: Entity.t()

  @doc """
  Gets called when the command topic receieves an `on_payload`
  """
  @callback handle_on(entity :: Entity.t()) :: entity :: Entity.t() | {:error, reason :: term()}

  @doc """
  Gets called when the command topic receieves an `off_payload`
  """
  @callback handle_off(entity :: Entity.t()) :: entity :: Entity.t() | {:error, reason :: term()}

  @doc """
  Gets called when a new brightness value gets published to the brightness command topic
  """
  @callback handle_brightness(entity :: Entity.t(), brightness :: float()) ::
              entity :: Entity.t() | {:error, reason :: term()}

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      use Homex.Entity, update_interval: opts[:update_interval]

      @behaviour Homex.Entity.Light
      @modes opts[:modes]

      @impl Homex.Entity
      def descriptor do
        %Homex.Descriptor{
          kind: :light,
          fields:
            Map.merge(
              %{state: :state},
              if(:brightness in unquote(opts[:modes]), do: %{brightness: :state}, else: %{})
            ),
          name: unquote(opts[:name]),
          options: %{modes: unquote(opts[:modes])},
          transport: %{mqtt: [retain: unquote(opts[:retain])]}
        }
      end

      @impl Homex.Entity
      def handle_command(cmd, entity) do
        entity
        |> apply_state(cmd)
        |> apply_brightness(cmd)
        |> apply_state_handler(cmd)
        |> apply_brightness_handler(cmd)
      end

      defp apply_state(entity, %{state: true}), do: set_on(entity)
      defp apply_state(entity, %{state: false}), do: set_off(entity)
      defp apply_state(entity, _cmd), do: entity

      defp apply_brightness(entity, %{brightness: value}) when :brightness in @modes,
        do: set_brightness(entity, value)

      defp apply_brightness(entity, _cmd), do: entity

      defp apply_state_handler(entity, %{state: true}), do: handle_on(entity)
      defp apply_state_handler(entity, %{state: false}), do: handle_off(entity)
      defp apply_state_handler(entity, _cmd), do: entity

      defp apply_brightness_handler(entity, %{brightness: value}) when :brightness in @modes,
        do: handle_brightness(entity, value)

      defp apply_brightness_handler(entity, _cmd), do: entity

      @impl Homex.Entity.Light
      def set_on(%Entity{} = entity), do: Entity.put_change(entity, :state, true)

      @impl Homex.Entity.Light
      def set_off(%Entity{} = entity), do: Entity.put_change(entity, :state, false)

      @impl Homex.Entity.Light
      def set_brightness(%Entity{} = entity, value) when value >= 0 and value <= 100,
        do: Entity.put_change(entity, :brightness, value)

      @impl Homex.Entity.Light
      def handle_on(entity), do: entity

      @impl Homex.Entity.Light
      def handle_off(entity), do: entity

      @impl Homex.Entity.Light
      def handle_brightness(entity, _brightness), do: entity

      @impl Homex.Entity
      def handle_init(entity) do
        entity = set_off(entity)
        entity = if :brightness in @modes, do: set_brightness(entity, 0), else: entity
        super(entity)
      end

      @impl Homex.Entity
      def handle_timer(entity), do: super(entity)

      defoverridable handle_on: 1,
                     handle_off: 1,
                     handle_brightness: 2,
                     handle_timer: 1,
                     handle_init: 1
    end
  end
end
