defmodule Homex.Entity.Number do
  use Homex.Entity

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
                 enabled_by_default: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc:
                     "Controls whether this entity is enabled by default. When set to true, the entity is enabled and usable immediately. Disabled entities are hidden by default until you enable them from the device page."
                 ],
                 visible_by_default: [
                   required: false,
                   type: :boolean,
                   default: true,
                   doc:
                     "Control whether this entity is visible by default. When set to false, the entity is hidden and does not appear on dashboards until you manually make it visible in its settings."
                 ],
                 min: [
                   required: false,
                   type: {:or, [:integer, :float]},
                   default: 1,
                   doc: "The minimum value that can be set or received."
                 ],
                 max: [
                   required: false,
                   type: {:or, [:integer, :float]},
                   default: 100,
                   doc: "The maximum value that can be set or received."
                 ],
                 step: [
                   required: false,
                   type: {:or, [:integer, :float]},
                   default: 1,
                   doc: "Step value. Smallest acceptable increment between the min and max value."
                 ],
                 mode: [
                   required: false,
                   type: {:in, [:auto, :box, :slider]},
                   default: :auto,
                   doc: "Control how the number should be displayed in the frontend."
                 ],
                 unit_of_measurement: [
                   required: false,
                   type: {:or, [nil, :string]},
                   default: nil,
                   doc: "The unit of measurement of the value."
                 ],
                 device_class: [
                   required: false,
                   type: {:or, [nil, :string]},
                   default: nil,
                   doc:
                     "Type of the number to set the icon and unit in the frontend. Available device classes: https://developers.home-assistant.io/docs/core/entity/number/#available-device-classes"
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
  A number entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  Home Assistant docs: https://www.home-assistant.io/integrations/number.mqtt

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MyNumber do
    use Homex.Entity.Number, id: :my_number, name: "My Number"

    def handle_number(entity, number) do
      IO.puts("Number set to \#{number}")
      entity
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  Gets called when the number has changed.
  """
  @callback handle_number(entity :: Entity.t(), number :: number()) :: entity :: Entity.t()

  @optional_callbacks handle_number: 2

  defmacro __using__(opts) do
    quote do
      unquote(Homex.Entity.__entity__(__MODULE__, opts, set_number: 2))

      def handle_number(entity, _number), do: entity
      defoverridable handle_number: 2
    end
  end

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    %Homex.Descriptor{
      kind: :number,
      fields: %{state: :state},
      name: opts[:name],
      options: %{
        enabled_by_default: opts[:enabled_by_default],
        visible_by_default: opts[:visible_by_default],
        min: opts[:min],
        max: opts[:max],
        step: opts[:step],
        mode: opts[:mode],
        unit_of_measurement: opts[:unit_of_measurement],
        device_class: opts[:device_class]
      },
      transport: %{mqtt: [retain: opts[:retain]]}
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity) do
    m.handle_init(entity)
  end

  @impl Homex.Entity
  def handle_command(%{state: number}, %{module: m} = entity),
    do: entity |> set_number(number) |> m.handle_number(number)

  def handle_command(_, entity), do: entity

  @doc """
  Sets the number
  """
  @spec set_number(Entity.t(), number :: number()) :: Entity.t()
  def set_number(%Entity{} = entity, number), do: Entity.put_change(entity, :state, number)
end
