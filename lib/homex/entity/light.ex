defmodule Homex.Entity.Light do
  use Homex.Entity

  alias Homex.Entity

  @type color() :: {:rgb, float(), float(), float()}
  @type mode() :: :on_off | :brightness | :rgb
  @implemented_modes [:on_off, :brightness, :rgb]

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
                 modes: [
                   required: false,
                   default: [:on_off],
                   type: {:list, {:in, @implemented_modes}},
                   type_doc: "list of `t:atom/0`",
                   doc:
                     "a list of supported light modes. Available: [#{@implemented_modes |> Enum.map(fn mode -> "`:#{mode}`" end) |> Enum.join(", ")}]"
                 ],
                 retain: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc: "if the last state should be retained"
                 ]
               )
               |> NimbleOptions.new!()

  @moduledoc """
  A light entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  https://www.home-assistant.io/integrations/light.mqtt/

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MyLight do
    use Homex.Entity.Light, id: :my_light, name: "My Light", modes: [:brightness]

    def handle_init(entity) do
      set_mode(entity, :brightness)
    end

    def handle_brightness(entity, brightness) do
      IO.puts("Light set to \#{round(brightness * 100)}%")
      entity
    end
  end
  ```

  ## Value ranges

  Brightness and the components of a color are always normalized to `0.0..1.0`.

  A color is the hue at full intensity, with its brightest component at `1.0`,
  and `brightness` acts as a multiplier for each color component.
  `{brightness * r, brightness * g, brightness * b}` would be the emitted RGB value.
  """

  @doc """
  Gets called when the light receives an on command
  """
  @callback handle_on(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the light receives an off command
  """
  @callback handle_off(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the light receives a new brightness value. Between 0 and 1
  """
  @callback handle_brightness(entity :: Entity.t(), brightness :: float()) ::
              entity :: Entity.t()

  @doc """
  Gets called when the light receives a new color value
  """
  @callback handle_color(entity :: Entity.t(), color :: color()) ::
              entity :: Entity.t()

  @doc """
  Gets called with the current mode.

  Call `Entity.changed?(entity, :mode, mode)` to know if it changed from the
  previous call.
  """
  @callback handle_mode(entity :: Entity.t(), mode :: mode()) ::
              entity :: Entity.t()

  @optional_callbacks handle_on: 1,
                      handle_off: 1,
                      handle_brightness: 2,
                      handle_color: 2,
                      handle_mode: 2

  defmacro __using__(opts) do
    quote do
      unquote(
        Homex.Entity.__entity__(__MODULE__, opts,
          set_on: 1,
          set_off: 1,
          set_brightness: 2,
          set_color: 2,
          set_mode: 2
        )
      )

      def handle_on(entity), do: entity
      def handle_off(entity), do: entity
      def handle_brightness(entity, _brightness), do: entity
      def handle_color(entity, _color), do: entity
      def handle_mode(entity, _mode), do: entity

      defoverridable handle_on: 1,
                     handle_off: 1,
                     handle_brightness: 2,
                     handle_color: 2,
                     handle_mode: 2
    end
  end

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    modes = opts[:modes]

    %Homex.Descriptor{
      kind: :light,
      fields: %{state: :state, brightness: :state, mode: :state, color: :state},
      name: opts[:name],
      options: %{modes: modes},
      transport: %{mqtt: [retain: opts[:retain]]}
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity) do
    mode = entity |> modes() |> selected_mode()

    entity
    |> set_mode(mode)
    |> set_off()
    |> set_defaults(mode)
    |> m.handle_init()
  end

  # the canonical list is ordered least to most capable, so filtering it by what
  # the entity declared picks the richest mode whatever order the option was given in
  defp selected_mode(modes), do: @implemented_modes |> Enum.filter(&(&1 in modes)) |> List.last()

  defp set_defaults(entity, :on_off), do: entity
  defp set_defaults(entity, :brightness), do: set_brightness(entity, 0.0)

  defp set_defaults(entity, :rgb),
    do: entity |> set_brightness(0.0) |> put_color({:rgb, 1.0, 1.0, 1.0})

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

  defp step({:state, true}, _entity, m), do: [{&set_on/1, &m.handle_on/1}]
  defp step({:state, false}, _entity, m), do: [{&set_off/1, &m.handle_off/1}]

  defp step({:brightness, v}, _entity, m),
    do: [{&set_brightness(&1, v), &m.handle_brightness(&1, v)}]

  defp step({:color, c}, _entity, m), do: [{&put_color(&1, c), &m.handle_color(&1, c)}]

  defp step({:mode, mode}, entity, m) do
    if mode in modes(entity), do: [{&set_mode(&1, mode), &m.handle_mode(&1, mode)}], else: []
  end

  defp step(_other, _entity, _m), do: []

  defp modes(entity), do: entity.descriptor.options.modes

  @doc """
  Sets the light state to on
  """
  @spec set_on(Entity.t()) :: Entity.t()
  def set_on(%Entity{} = entity), do: Entity.put_change(entity, :state, true)

  @doc """
  Sets the light state to off
  """
  @spec set_off(Entity.t()) :: Entity.t()
  def set_off(%Entity{} = entity), do: Entity.put_change(entity, :state, false)

  @doc """
  Sets the lights brightness to the specified value. Must be between 0 and 1
  """
  @spec set_brightness(Entity.t(), number()) :: Entity.t()
  def set_brightness(%Entity{} = entity, value) when value >= 0 and value <= 1,
    do: Entity.put_change(entity, :brightness, value)

  @doc """
  Sets the color the light emits. Each component must be between 0 and 1.

  The color you pass is the color it emits, so a value that is not at full
  intensity dims the light too: `{:rgb, 0.1, 0.2, 0.3}` sets the hue
  `{:rgb, 0.33, 0.67, 1.0}` and the brightness `0.3`. Call `set_brightness/2`
  afterwards to keep the hue and dim it differently. Black keeps the current hue
  and turns the brightness down to zero.
  """
  @spec set_color(Entity.t(), color()) :: Entity.t()
  def set_color(%Entity{} = entity, {:rgb, r, g, b})
      when r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1 do
    case Enum.max([r, g, b]) do
      peak when peak > 0 ->
        entity |> put_color({:rgb, r / peak, g / peak, b / peak}) |> set_brightness(peak)

      _black ->
        set_brightness(entity, 0.0)
    end
  end

  # the hue on its own, for a caller that already keeps the brightness apart
  defp put_color(entity, {:rgb, _r, _g, _b} = color),
    do: Entity.put_change(entity, :color, color)

  @doc """
  Sets the lights color to the specified value
  """
  @spec set_mode(Entity.t(), mode()) :: Entity.t()
  def set_mode(%Entity{} = entity, mode) do
    if mode not in modes(entity) do
      raise ArgumentError, "light mode #{mode} not supported"
    else
      Entity.put_change(entity, :mode, mode)
    end
  end
end
