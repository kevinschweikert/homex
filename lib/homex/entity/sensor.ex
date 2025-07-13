defmodule Homex.Entity.Sensor do
  @opts_schema [
                 name: [required: true, type: :string, doc: "the name of the entity"],
                 update_interval: [
                   required: false,
                   type: {:or, [:atom, :integer]},
                   default: 10_000,
                   doc:
                     "the interval in milliseconds in which `handle_timer/1` get's called. Can also be `:never` to disable the timer callback"
                 ],
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
               ]
               |> NimbleOptions.new!()

  @moduledoc """
  A sensor entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  https://www.home-assistant.io/integrations/sensor.mqtt/

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Overridable Functions

  The following functions can be overridden in your entity:

  * `handle_init/1` - From `Homex.Entity`
  * `handle_timer/1` - From `Homex.Entity`

  ### Default Implementations

  All overridable functions have safe default implementations that return the entity unchanged.
  You only need to override the functions you want to customize.

  ## Example

  ```elixir
  defmodule MyTemperature do
    use Homex.Entity.Sensor,
      name: "my-temperature",
      unit_of_measurement: "°C",
      device_class: "temperature"

    def handle_timer(entity) do
      value = Sensor.read()
      entity |> set_value(value)
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  Sets the entity value
  """
  @callback set_value(entity :: Entity.t(), value :: term()) :: entity :: Entity.t()

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      use Homex.Entity, update_interval: opts[:update_interval]
      @behaviour Homex.Entity.Sensor

      @name opts[:name]
      @platform "sensor"
      @unique_id Homex.unique_id(@name, [@platform, __MODULE__])
      @state_topic "homex/#{@platform}/#{@unique_id}"
      @unit_of_measurement opts[:unit_of_measurement]
      @device_class opts[:device_class]
      @state_class opts[:state_class]
      @retain opts[:retain]

      @impl Homex.Entity
      def name, do: @name

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def subscriptions, do: []

      @impl Homex.Entity
      def platform(), do: @platform

      @impl Homex.Entity
      def config do
        %{
          platform: @platform,
          state_topic: @state_topic,
          name: @name,
          unique_id: @unique_id,
          device_class: @device_class,
          unit_of_measurement: @unit_of_measurement,
          state_class: @state_class
        }
        |> Map.reject(fn {_key, val} -> is_nil(val) end)
      end

      @impl Homex.Entity
      def setup_entity(entity) do
        entity
        |> Entity.register_handler(:state, fn val ->
          Homex.publish(@state_topic, val, retain: @retain)
        end)
      end

      @impl Homex.Entity.Sensor
      def set_value(%Entity{} = entity, value) do
        Entity.put_change(entity, :state, value)
      end

      @impl Homex.Entity
      def handle_init(entity), do: super(entity)

      @impl Homex.Entity
      def handle_timer(entity), do: super(entity)

      defoverridable handle_init: 1, handle_timer: 1
    end
  end
end
