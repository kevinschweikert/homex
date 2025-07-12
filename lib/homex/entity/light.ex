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

  https://www.home-assistant.io/integrations/light.mqtt/

  Options:

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MyLight do
    use Homex.Entity.Light, name: "my-light"

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
  Configures the intial state for the light
  """
  @callback handle_init(entity :: Entity.t()) :: entity :: Entity.t() | {:error, reason :: term()}

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

  @doc """
  If an `update_interval` is set, this callback will be fired. By default the `update_interval` is set to `:never`
  """
  @callback handle_timer(entity :: Entity.t()) :: {:noreply, Entity.t()}

  @doc false
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

  @doc false
  def mode_or(modes, mode, term, default \\ nil) do
    if mode in modes do
      term
    else
      default
    end
  end

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      @behaviour Homex.Entity
      @behaviour Homex.Entity.Light
      import Homex.Entity
      import Homex.Entity.Light

      @name opts[:name]
      @modes opts[:modes]
      @platform "light"
      @unique_id Homex.unique_id(@name, [@platform, __MODULE__])
      @state_topic "homex/#{@platform}/#{@unique_id}"
      @command_topic "homex/#{@platform}/#{@unique_id}/set"
      @brightness_state_topic mode_or(
                                @modes,
                                :brightness,
                                "homex/#{@platform}/#{@unique_id}/brightness"
                              )
      @brightness_command_topic mode_or(
                                  @modes,
                                  :brightness,
                                  "homex/#{@platform}/#{@unique_id}/brightness/set"
                                )
      @on_payload "ON"
      @off_payload "OFF"
      @retain opts[:retain]
      @update_interval opts[:update_interval]

      use GenServer

      def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

      @impl Homex.Entity
      def name, do: @name

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def subscriptions do
        [@command_topic, mode_or(@modes, :brightness, @brightness_command_topic, [])]
        |> List.flatten()
      end

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
          name: @name,
          unique_id: @unique_id
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
          |> Entity.register_handler(:brightness, fn val ->
            Homex.publish(@brightness_state_topic, val, retain: @retain)
          end)

        entity
        |> handle_init()
        |> Entity.execute_from_init()
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
      def handle_info({@command_topic, @on_payload}, entity) do
        entity
        |> set_on()
        |> handle_on()
        |> Entity.execute_from_handle_info(entity)
      end

      def handle_info({@command_topic, @off_payload}, entity) do
        entity
        |> set_off()
        |> handle_off()
        |> Entity.execute_from_handle_info(entity)
      end

      def handle_info({@brightness_command_topic, brightness}, entity) do
        with {:ok, value} <- convert_brightness(brightness) do
          entity
          |> set_brightness(value)
          |> handle_brightness(value)
          |> Entity.execute_from_handle_info(entity)
        end
      end

      def handle_info({other_topic, _payload}, entity) when is_binary(other_topic) do
        {:noreply, entity}
      end

      def handle_info(:update, entity) do
        entity
        |> handle_timer()
        |> Entity.execute_from_handle_info(entity)
      end

      @impl Homex.Entity.Light
      def handle_init(entity) do
        {:ok, entity}
      end

      @impl Homex.Entity.Light
      def handle_timer(entity), do: entity

      @impl Homex.Entity.Light
      def handle_on(entity), do: entity

      @impl Homex.Entity.Light
      def handle_off(entity), do: entity

      @impl Homex.Entity.Light
      def handle_brightness(entity, _brightness), do: entity

      defoverridable handle_on: 1,
                     handle_off: 1,
                     handle_brightness: 2,
                     handle_timer: 1,
                     handle_init: 1
    end
  end
end
