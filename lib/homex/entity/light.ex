defmodule Homex.Entity.Light do
  @moduledoc ~S"""
  A light entity for Homex

  https://www.home-assistant.io/integrations/light.mqtt/

  Options:

  - `name` (required)
  - `update_interval`
  - `on_payload`
  - `off_payload`

  To publish a new state return `{:reply, [state: on(), brightness: 123], state}` from the handler. Otherwise return `{:noreply, state}`.

  ## Example

  ```elixir
  defmodule MyLight do
    use Homex.Entity.Light, name: "my-light"

    def handle_brightness(brightness, state) do
      {:ok, percentage} = convert_brightness(brightness)
      IO.puts("Light set to #{percentage}%")
      {:reply, [brightness: brightness], state}
    end
  end
  ```
  """

  alias Homex.Entity

  @callback set_on(Entity.t()) :: Entity.t()
  @callback set_off(Entity.t()) :: Entity.t()
  @callback set_brightness(Entity.t(), float()) :: Entity.t()
  @doc """
  The intial state for the light
  """
  @callback handle_init(Entity.t()) :: {:ok, Entity.t()}

  @doc """
  Gets called when the command topic receieves an `on_payload`
  """
  @callback handle_on(Entity.t()) :: {:noreply, Entity.t()}

  @doc """
  Gets called when the command topic receieves an `off_payload`
  """
  @callback handle_off(Entity.t()) :: {:noreply, Entity.t()}
  @doc """
  Gets called when a new brightness value gets published to the brightness command topic 
  """
  @callback handle_brightness(float(), Entity.t()) :: {:noreply, Entity.t()}

  @doc """
  If an `update_interval` is set, this callback will be fired. By default the `update_interval` is set to `:never`
  """
  @callback handle_timer(Entity.t()) :: {:noreply, Entity.t()}

  @doc """
  converts a string representing an 8-bit value to a percentage from 0 to 100"

  ## Example

      iex> Homex.Entity.Light.convert_brightness("123")
      {:ok, 48.24}

      iex> Homex.Entity.Light.convert_brightness("1000")
      {:error, :invalid_brightness}

      iex> Homex.Entity.Light.convert_brightness("abc")
      {:error, :invalid_brightness}
  """
  @spec convert_brightness(String.t(), integer()) ::
          {:ok, float()} | {:error, :invalid_brightness}
  def convert_brightness(brightness, precision \\ 2) when is_binary(brightness) do
    with {value, ""} when value >= 0 and value <= 255 <- Integer.parse(brightness) do
      percentage = value * 100 / 255
      {:ok, Float.round(percentage, precision)}
    else
      _ -> {:error, :invalid_brightness}
    end
  end

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts], generated: true do
      @behaviour Homex.Entity
      @behaviour Homex.Entity.Light
      import Homex.Entity.Light

      @name Keyword.fetch!(opts, :name)
      @platform "light"
      @entity_id Homex.entity_id(@name)
      @unique_id Homex.unique_id(@platform, @name)
      @state_topic "homex/#{@platform}/#{@entity_id}"
      @command_topic "homex/#{@platform}/#{@entity_id}/set"
      @brightness_state_topic "homex/#{@platform}/#{@entity_id}/brightness"
      @brightness_command_topic "homex/#{@platform}/#{@entity_id}/brightness/set"
      @update_interval Keyword.get(opts, :update_interval, :never)
      @on_payload Keyword.get(opts, :on_payload, "ON")
      @off_payload Keyword.get(opts, :off_payload, "OFF")

      use GenServer

      def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

      @impl Homex.Entity
      def entity_id, do: @entity_id

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def subscriptions, do: [@command_topic, @brightness_command_topic]

      @impl Homex.Entity
      def platform(), do: @platform

      @impl Homex.Entity
      def config do
        %{
          platform: @platform,
          state_topic: @state_topic,
          command_topic: @command_topic,
          brightness_state_topic: @brightness_state_topic,
          brightness_command_topic: @brightness_command_topic,
          name: @entity_id,
          unique_id: @unique_id
        }
      end

      @impl Homex.Entity.Light
      def set_on(%Entity{} = entity) do
        Entity.put_change(entity, :state, @on_payload)
      end

      @impl Homex.Entity.Light
      def set_off(%Entity{} = entity) do
        Entity.put_change(entity, :state, @off_payload)
      end

      @impl Homex.Entity.Light
      def set_brightness(%Entity{} = entity, value) when value >= 0 and value <= 100 do
        Entity.put_change(entity, :brightness, Float.round(value / 100 * 255, 0))
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
          |> Entity.register_handler(:brightness, fn val ->
            Homex.publish(@brightness_state_topic, val)
          end)

        with {:ok, entity} <- handle_init(entity) do
          {:ok, Entity.execute_change(entity)}
        end
      end

      @impl GenServer
      def handle_info({@command_topic, @on_payload}, entity) do
        with entity <- set_on(entity),
             {:noreply, entity} <- handle_on(entity) do
          {:noreply, Entity.execute_change(entity)}
        end
      end

      def handle_info({@command_topic, @off_payload}, entity) do
        with entity <- set_off(entity),
             {:noreply, entity} <- handle_off(entity) do
          {:noreply, Entity.execute_change(entity)}
        end
      end

      def handle_info({@brightness_command_topic, brightness}, entity) do
        with {:ok, value} <- convert_brightness(brightness),
             entity <- set_brightness(entity, brightness),
             {:noreply, entity} <- handle_brightness(value, entity) do
          {:noreply, Entity.execute_change(entity)}
        end
      end

      def handle_info({other_topic, _payload}, entity) when is_binary(other_topic) do
        {:noreply, entity}
      end

      def handle_info(:update, entity) do
        with {:noreply, entity} <- handle_timer(entity) do
          {:noreply, Entity.execute_change(entity)}
        end
      end

      @impl Homex.Entity.Light
      def handle_init(entity) do
        {:ok, entity}
      end

      @impl Homex.Entity.Light
      def handle_timer(entity) do
        {:noreply, entity}
      end

      @impl Homex.Entity.Light
      def handle_on(entity) do
        {:noreply, entity}
      end

      @impl Homex.Entity.Light
      def handle_off(entity) do
        {:noreply, entity}
      end

      @impl Homex.Entity.Light
      def handle_brightness(brightness, entity) do
        {:noreply, entity}
      end

      defoverridable handle_on: 1,
                     handle_off: 1,
                     handle_brightness: 2,
                     handle_timer: 1,
                     handle_init: 1
    end
  end
end
