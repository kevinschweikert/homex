defmodule Homex.Entity.Sensor do
  use Homex.Entity

  @opts_schema Homex.Entity.base_opts_schema()
               |> Keyword.merge(
                 retain: [
                   required: false,
                   type: :boolean,
                   default: false,
                   doc: "if the last state should be retained"
                 ],
                 state_class: [
                   required: false,
                   type: {:or, [nil, :string]},
                   default: nil,
                   doc:
                     "Type of state. If not `nil`, the sensor is assumed to be numerical and will be displayed as a line-chart in the frontend instead of as discrete values."
                 ],
                 device_class: [
                   required: false,
                   type: {:or, [nil, :string]},
                   default: nil,
                   doc:
                     "Type of sensor. Available device classes: https://developers.home-assistant.io/docs/core/entity/sensor/#available-device-classes"
                 ],
                 unit_of_measurement: [
                   required: false,
                   default: nil,
                   type: {:or, [nil, :string]},
                   doc:
                     "The unit of measurement that the sensor's value is expressed in. Available units in depending on device class (see second column): https://developers.home-assistant.io/docs/core/entity/sensor/#available-device-classes"
                 ]
               )
               |> NimbleOptions.new!()

  @moduledoc """
  A sensor entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  https://www.home-assistant.io/integrations/sensor.mqtt/

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MyTemperature do
    use Homex.Entity.Sensor,
      id: :my_temperature,
      name: "My Temperature",
      unit_of_measurement: "°C",
      device_class: "temperature"

    def handle_init(entity) do
      :timer.send_interval(10_000, :measure)
      entity
    end

    def handle_info(:measure, entity) do
      set_value(entity, Sensor.read())
    end
  end
  ```
  """

  alias Homex.Entity

  defmacro __using__(opts), do: Homex.Entity.__entity__(__MODULE__, opts, set_value: 2)

  @impl Homex.Entity
  def validate(opts) do
    NimbleOptions.validate(opts, @opts_schema)
  end

  @impl Homex.Entity
  def describe(opts) do
    %Homex.Descriptor{
      kind: :sensor,
      fields: %{state: :state},
      name: opts[:name],
      options: %{
        device_class: opts[:device_class],
        unit_of_measurement: opts[:unit_of_measurement],
        state_class: opts[:state_class]
      },
      transport: %{mqtt: [retain: opts[:retain]]}
    }
  end

  @impl Homex.Entity
  def setup(%{module: m} = entity), do: m.handle_init(entity)

  @impl Homex.Entity
  def handle_command(_cmd, entity), do: entity

  @doc """
  Sets the entity value
  """
  @spec set_value(Entity.t(), term()) :: Entity.t()
  def set_value(%Entity{} = entity, value), do: Entity.put_change(entity, :state, value)
end
