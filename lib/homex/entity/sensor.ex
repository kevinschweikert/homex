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

  https://www.home-assistant.io/integrations/sensor.mqtt/

  Options:

  #{NimbleOptions.docs(@opts_schema)}

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

  @doc """
  Configures the intial state for the sensor
  """
  @callback handle_init(entity :: Entity.t()) :: entity :: Entity.t() | {:error, reason :: term()}

  @doc """
  If an `update_interval` is set, this callback will be fired. By default the `update_interval` is set to `5000`
  """
  @callback handle_timer(entity :: Entity.t()) ::
              entity :: Entity.t() | {:error, reason :: term()}

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      @behaviour Homex.Entity
      @behaviour Homex.Entity.Sensor

      @name opts[:name]
      @platform "sensor"
      @unique_id Homex.unique_id(@platform, @name)
      @state_topic "homex/#{@platform}/#{@unique_id}"
      @update_interval opts[:update_interval]
      @unit_of_measurement opts[:unit_of_measurement]
      @device_class opts[:device_class]
      @state_class opts[:state_class]
      @retain opts[:retain]

      use GenServer

      def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

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

      @impl GenServer
      def init(_init_arg \\ []) do
        case @update_interval do
          :never -> :ok
          time -> :timer.send_interval(time, :update)
        end

        entity =
          %Entity{}
          |> Entity.register_handler(:state, fn val ->
            Homex.publish(@state_topic, val, retain: @retain)
          end)

        entity
        |> handle_init()
        |> Entity.execute_from_init()
      end

      @impl Homex.Entity.Sensor
      def set_value(%Entity{} = entity, value) do
        Entity.put_change(entity, :state, value)
      end

      @impl GenServer
      def handle_info({other_topic, _payload}, state) when is_binary(other_topic) do
        {:noreply, state}
      end

      def handle_info(:update, entity) do
        entity
        |> handle_timer()
        |> Entity.execute_from_handle_info(entity)
      end

      @impl Homex.Entity.Sensor
      def handle_init(entity), do: entity

      @impl Homex.Entity.Sensor
      def handle_timer(entity), do: entity

      defoverridable handle_init: 1, handle_timer: 1
    end
  end
end
