defmodule Homex.Entity.Light do
  use Homex.Entity

  @implemented_modes [:brightness]

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
                 modes: [
                   required: false,
                   default: [],
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

    def handle_brightness(entity, brightness) do
      IO.puts("Light set to \#{brightness}%")
      entity
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  Gets called when the light receives an on command
  """
  @callback handle_on(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the light receives an off command
  """
  @callback handle_off(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the light receives a new brightness value. Between 0 and 100
  """
  @callback handle_brightness(entity :: Entity.t(), brightness :: float()) ::
              entity :: Entity.t()

  @optional_callbacks handle_on: 1, handle_off: 1, handle_brightness: 2

  defmacro __using__(opts) do
    quote do
      unquote(Homex.Entity.__entity__(__MODULE__, opts, set_on: 1, set_off: 1, set_brightness: 2))

      def handle_on(entity), do: entity
      def handle_off(entity), do: entity
      def handle_brightness(entity, _brightness), do: entity
      defoverridable handle_on: 1, handle_off: 1, handle_brightness: 2
    end
  end

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    modes = opts[:modes]

    fields =
      if :brightness in modes,
        do: %{state: :state, brightness: :state},
        else: %{state: :state}

    %Homex.Descriptor{
      kind: :light,
      fields: fields,
      name: opts[:name],
      options: %{modes: modes},
      transport: %{mqtt: [retain: opts[:retain]]}
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity) do
    entity = set_off(entity)
    entity = if :brightness in modes(entity), do: set_brightness(entity, 0), else: entity
    m.handle_init(entity)
  end

  @impl Homex.Entity
  def handle_command(cmd, entity) do
    cmd = supported(cmd, entity)

    entity
    |> set_fields(cmd)
    |> notify_handler(cmd)
  end

  defp supported(cmd, entity) do
    if :brightness in modes(entity), do: cmd, else: Map.delete(cmd, :brightness)
  end

  defp set_fields(entity, cmd) do
    entity =
      case cmd do
        %{state: true} -> set_on(entity)
        %{state: false} -> set_off(entity)
        _ -> entity
      end

    case cmd do
      %{brightness: value} -> set_brightness(entity, value)
      _ -> entity
    end
  end

  defp notify_handler(%{module: m} = entity, cmd) do
    entity =
      case cmd do
        %{state: true} -> m.handle_on(entity)
        %{state: false} -> m.handle_off(entity)
        _ -> entity
      end

    case cmd do
      %{brightness: value} -> m.handle_brightness(entity, value)
      _ -> entity
    end
  end

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
  Sets the lights brightness to the specified value. Must be between 0 and 100
  """
  @spec set_brightness(Entity.t(), number()) :: Entity.t()
  def set_brightness(%Entity{} = entity, value) when value >= 0 and value <= 100,
    do: Entity.put_change(entity, :brightness, value)
end
