defmodule Homex.Entity.Climate do
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
                   default: true,
                   doc: "if the last state should be retained"
                 ],
                 modes: [
                   required: false,
                   type: {:list, :string},
                   default: ["auto", "off", "cool", "heat", "dry", "fan_only"],
                   doc: "A list of supported modes. Needs to be a subset of the default values."
                 ],
                 max_temp: [
                   required: false,
                   type: {:or, [:float, nil]},
                   default: nil,
                   doc:
                     "Maximum set point available. The default value depends on the temperature unit, and will be 35°C or 95°F"
                 ],
                 min_temp: [
                   required: false,
                   type: {:or, [:float, nil]},
                   default: nil,
                   doc:
                     "Minimum set point available. The default value depends on the temperature unit, and will be 7°C or 44.6°F."
                 ],
                 precision: [
                   required: false,
                   type: {:or, [:float, nil]},
                   default: nil,
                   doc:
                     "The desired precision for this device. Can be used to match your actual thermostat’s precision. Supported values are 0.1, 0.5 and 1.0."
                 ],
                 include_temperature_low_high: [
                   required: false,
                   type: :boolean,
                   default: false,
                   doc:
                     "Enables the subscription to the temperature_high_command_topic and temperature_low_command_topic."
                 ]
               ]
               |> NimbleOptions.new!()

  @moduledoc """
  A climate HVAC entity for Homex

  Implements a `Homex.Entity`. See module for available callbacks.

  Home Assistant docs: https://www.home-assistant.io/integrations/climate.mqtt

  ## Options

  #{NimbleOptions.docs(@opts_schema)}

  ## Overridable Functions

  The following functions can be overridden in your entity:

  * `handle_init/1` - From `Homex.Entity`
  * `handle_timer/1` - From `Homex.Entity`
  * `handle_mode/2` - From `Homex.Entity.Climate`
  * `handle_target_temperature/2` - From `Homex.Entity.Climate`

  ### Default Implementations

  All overridable functions have safe default implementations that return the entity unchanged.
  You only need to override the functions you want to customize.

  ## Example

  ```elixir
  defmodule MyHVAC do
    use Homex.Entity.Climate, name: "my-hvac"

    @impl Homex.Entity.Climate
    def handle_mode(entity, mode) do
      dbg(mode)
    end

    @impl Homex.Entity.Climate
    def handle_target_temperature(entity, target) do
      dbg(target)
    end

    @impl Homex.Entity
    def handle_timer(entity) do
      entity |> set_current_temperature(22.0)
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  Sets the climate HVAC mode
  """
  @callback set_mode(entity :: Entity.t(), mode :: String.t()) :: entity :: Entity.t()

  @doc """
  Sets the climate HVAC target temperature
  """
  @callback set_target_temperature(entity :: Entity.t(), target :: Float.t()) ::
              entity :: Entity.t()

  @doc """
  Sets the climate HVAC current temperature
  """
  @callback set_current_temperature(entity :: Entity.t(), target :: Float.t()) ::
              entity :: Entity.t()

  @doc """
  Sets the climate HVAC current humidity
  """
  @callback set_current_humidity(entity :: Entity.t(), target :: Float.t()) ::
              entity :: Entity.t()
  @doc """
  Gets called when the mode command topic is receieved
  """
  @callback handle_mode(entity :: Entity.t(), mode :: String.t()) :: entity :: Entity.t()

  @doc """
  Gets called when the temperature command topic is receieved
  """
  @callback handle_target_temperature(entity :: Entity.t(), target :: float()) :: entity :: Entity.t()

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      use Homex.Entity, update_interval: opts[:update_interval]

      @behaviour Homex.Entity.Climate

      @name opts[:name]
      @platform "climate"
      @unique_id Homex.unique_id(@name, [@platform])
      @current_humidity_topic "homex/#{@platform}/#{@unique_id}/current_humidity"
      @current_temperature_topic "homex/#{@platform}/#{@unique_id}/current_temperature"
      @mode_command_topic "homex/#{@platform}/#{@unique_id}/set_mode"
      @mode_state_topic "homex/#{@platform}/#{@unique_id}/mode"
      @temperature_command_topic "homex/#{@platform}/#{@unique_id}/set_target"
      @temperature_state_topic "homex/#{@platform}/#{@unique_id}/target"
      @temperature_low_state_topic "homex/#{@platform}/#{@unique_id}/target_low"
      @temperature_high_state_topic "homex/#{@platform}/#{@unique_id}/target_high"
      @precision opts[:precision]
      @min_temp opts[:min_temp]
      @max_temp opts[:max_temp]
      @modes opts[:modes]
      @retain opts[:retain]
      @include_temperature_low_high opts[:include_temperature_low_high]

      @doc """
      Publishes the mode via the mode_state_topic.
      """
      def set_mode(val) when is_binary(val) and val in @modes,
        do: GenServer.cast(__MODULE__, {:mode, val})

      @doc """
      Publishes the current humidity via the current_humidity_topic.
      """
      def set_current_humidity(val) when is_float(val),
        do: GenServer.cast(__MODULE__, {:current_humidity, val})

      @doc """
      Publishes the current temperature via the current_temperature_topic.
      """
      def set_current_temperature(val) when is_float(val),
        do: GenServer.cast(__MODULE__, {:current_temperature, val})

      @doc """
      Publishes a target temperature via the temperature_state_topic.
      """
      def set_target_temperature(val) when is_float(val),
        do: GenServer.cast(__MODULE__, {:target_temperature, val})

      @doc """
      Publishes a new lower target temperature via the temperature_low_state_topic.
      """
      def set_target_temperature_low(val) when is_float(val),
        do: GenServer.cast(__MODULE__, {:target_temperature_low, val})

      @doc """
      Publishes a new upper target temperature via the temperature_high_state_topic.
      """
      def set_target_temperature_high(val) when is_float(val),
        do: GenServer.cast(__MODULE__, {:target_temperature_high, val})

      @impl Homex.Entity
      def name, do: @name

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def subscriptions, do: [@mode_command_topic, @temperature_command_topic]

      @impl Homex.Entity
      def platform(), do: @platform

      @impl Homex.Entity
      def config do
        %{
          platform: @platform,
          name: @name,
          current_humidity_topic: @current_humidity_topic,
          current_temperature_topic: @current_temperature_topic,
          mode_command_topic: @mode_command_topic,
          mode_state_topic: @mode_state_topic,
          temperature_command_topic: @temperature_command_topic,
          temperature_state_topic: @temperature_state_topic,
          precision: @precision,
          min_temp: @min_temp,
          max_temp: @max_temp,
          modes: @modes,
          unique_id: @unique_id
        }
        |> append_if_set(
          @include_temperature_low_high,
          :temperature_low_state_topic,
          @temperature_low_state_topic
        )
        |> append_if_set(
          @include_temperature_low_high,
          :temperature_high_state_topic,
          @temperature_high_state_topic
        )
        |> append_if_set(:precision, @precision)
        |> append_if_set(:min_temp, @min_temp)
        |> append_if_set(:max_temp, @max_temp)
      end

      @impl Homex.Entity
      def setup_entity(entity) do
        entity
        |> Entity.register_handler(:mode, fn val ->
          Homex.publish(@mode_state_topic, val, retain: @retain)
        end)
        |> Entity.register_handler(:current_temperature, fn val ->
          Homex.publish(@current_temperature_topic, val, retain: @retain)
        end)
        |> Entity.register_handler(:current_humidity, fn val ->
          Homex.publish(@current_humidity_topic, val, retain: @retain)
        end)
        |> Entity.register_handler(:target_temperature, fn val ->
          Homex.publish(@temperature_state_topic, val, retain: @retain)
        end)
        |> Entity.register_handler(:target_temperature_low, fn val ->
          Homex.publish(@temperature_low_state_topic, val, retain: @retain)
        end)
        |> Entity.register_handler(:target_temperature_high, fn val ->
          Homex.publish(@temperature_high_state_topic, val, retain: @retain)
        end)
      end

      @impl Homex.Entity
      def handle_message({@mode_command_topic, new_mode}, entity) when new_mode in @modes do
        entity |> set_mode(new_mode) |> handle_mode(new_mode)
      end

      def handle_message({@temperature_command_topic, new_target}, entity) do
        new_target = new_target |> Float.parse() |> elem(0)
        entity |> set_target_temperature(new_target) |> handle_target_temperature(new_target)
      end

      @impl Homex.Entity.Climate
      def set_mode(%Entity{} = entity, mode) do
        Entity.put_change(entity, :mode, mode)
      end

      @impl Homex.Entity.Climate
      def set_target_temperature(%Entity{} = entity, mode) do
        Entity.put_change(entity, :target_temperature, mode)
      end

      @impl Homex.Entity.Climate
      def set_current_temperature(%Entity{} = entity, mode) do
        Entity.put_change(entity, :current_temperature, mode)
      end

      @impl Homex.Entity.Climate
      def set_current_humidity(%Entity{} = entity, mode) do
        Entity.put_change(entity, :current_humidity, mode)
      end

      @impl Homex.Entity.Climate
      def handle_mode(entity, mode), do: entity

      @impl Homex.Entity.Climate
      def handle_target_temperature(entity, target), do: entity

      @impl Homex.Entity
      def handle_init(entity), do: super(entity)

      @impl Homex.Entity
      def handle_timer(entity), do: super(entity)

      @impl GenServer
      def handle_cast({:mode, val}, entity) do
        entity = entity |> Entity.put_change(:mode, val) |> Entity.execute_change()
        {:noreply, entity}
      end

      def handle_cast({:current_temperature, val}, entity) do
        entity = entity |> Entity.put_change(:current_temperature, val) |> Entity.execute_change()
        {:noreply, entity}
      end

      def handle_cast({:current_humidity, val}, entity) do
        entity = entity |> Entity.put_change(:current_humidity, val) |> Entity.execute_change()
        {:noreply, entity}
      end

      def handle_cast({:target_temperature, val}, entity) do
        entity = entity |> Entity.put_change(:target_temperature, val) |> Entity.execute_change()
        {:noreply, entity}
      end

      def handle_cast({:target_temperature_low, val}, entity) do
        entity =
          entity |> Entity.put_change(:target_temperature_low, val) |> Entity.execute_change()

        {:noreply, entity}
      end

      def handle_cast({:target_temperature_high, val}, entity) do
        entity =
          entity |> Entity.put_change(:target_temperature_high, val) |> Entity.execute_change()

        {:noreply, entity}
      end

      defp append_if_set(config, _key, nil), do: config
      defp append_if_set(config, key, value), do: Map.put(config, key, value)
      defp append_if_set(config, false, _key, _value), do: config
      defp append_if_set(config, true, key, value), do: Map.put(config, key, value)

      defoverridable handle_init: 1, handle_mode: 2, handle_target_temperature: 2, handle_timer: 1
    end
  end
end
