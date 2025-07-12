defmodule Homex.Entity.Sensor do
  @moduledoc """
  A sensor entity for Homex

  https://www.home-assistant.io/integrations/sensor.mqtt/

  Options:

  - `name` (required)
  - `update_interval`
  - `unit_of_measurement`
  - `device_class`

  Available device classes: https://www.home-assistant.io/integrations/sensor#device-class

  ## Example

  ```elixir
  defmodule MyTemperature do
    use Homex.Entity.Sensor,
      name: "my-temperature",
      unit_of_measurement: Homex.Unit.temperature(:c),
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
    quote bind_quoted: [opts: opts], generated: true do
      @behaviour Homex.Entity
      @behaviour Homex.Entity.Sensor

      @name Keyword.fetch!(opts, :name)
      @platform "sensor"
      @entity_id Homex.entity_id(@name)
      @unique_id Homex.unique_id(@platform, @name)
      @state_topic "homex/#{@platform}/#{@entity_id}"
      @update_interval Keyword.get(opts, :update_interval, 5000)
      @unit_of_measurement opts[:unit_of_measurement]
      @device_class opts[:device_class]

      use GenServer

      def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

      @impl Homex.Entity
      def entity_id, do: @entity_id

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
          name: @entity_id,
          unique_id: @unique_id,
          device_class: @device_class,
          unit_of_measurement: @unit_of_measurement
        }
      end

      @impl GenServer
      def init(_init_arg \\ []) do
        case @update_interval do
          :never -> :ok
          time -> :timer.send_interval(time, :update)
        end

        entity =
          %Entity{}
          |> Entity.register_handler(:state, fn val -> Homex.publish(@state_topic, val) end)

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
