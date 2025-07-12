defmodule Homex.Entity.Switch do
  @opts_schema [
                 name: [required: true, type: :string, doc: "the name of the entity"],
                 update_interval: [
                   required: false,
                   type: {:or, [:atom, :integer]},
                   default: :never,
                   doc:
                     "the interval in milliseconds in which `handle_timer/1` get's called. Can also be `:never` to disable the timer callback"
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
  A switch entity for Homex

  Home Assistant docs: https://www.home-assistant.io/integrations/switch.mqtt

  Options:

  #{NimbleOptions.docs(@opts_schema)}

  ## Example

  ```elixir
  defmodule MySwitch do
    use Homex.Entity.Switch, name: "my-switch"

    def handle_on(entity) do
      IO.puts("Switch turned on")
      entity
    end

    def handle_off(entity) do
      IO.puts("Switch turned off")
      entity
    end
  end
  ```
  """

  alias Homex.Entity

  @doc """
  Sets the switch state to on
  """
  @callback set_on(entity :: Entity.t()) :: entity :: Entity.t()
  @doc """
  Sets the switch state to off
  """
  @callback set_off(entity :: Entity.t()) :: entity :: Entity.t()

  @doc """
  Configures the intial state for the switch
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
  If an `update_interval` is set, this callback will be fired. By default the `update_interval` is set to `:never`
  """
  @callback handle_timer(entity :: Entity.t()) ::
              entity :: Entity.t() | {:error, reason :: term()}

  defmacro __using__(opts) do
    opts = NimbleOptions.validate!(opts, @opts_schema)

    quote bind_quoted: [opts: opts], generated: true do
      @behaviour Homex.Entity
      @behaviour Homex.Entity.Switch

      @name opts[:name]
      @platform "switch"
      @unique_id Homex.unique_id(@platform, @name)
      @state_topic "homex/#{@platform}/#{@unique_id}"
      @command_topic "homex/#{@platform}/#{@unique_id}/set"
      @on_payload "ON"
      @off_payload "OFF"
      @update_interval opts[:update_interval]
      @retain opts[:retain]

      use GenServer

      def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

      @impl Homex.Entity
      def name, do: @name

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def subscriptions, do: [@command_topic]

      @impl Homex.Entity
      def platform(), do: @platform

      @impl Homex.Entity
      def config do
        %{
          platform: @platform,
          state_topic: @state_topic,
          command_topic: @command_topic,
          name: @name,
          unique_id: @unique_id
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
          |> Entity.register_handler(:state, fn val ->
            Homex.publish(@state_topic, val, retain: @retain)
          end)

        entity
        |> handle_init()
        |> Entity.execute_from_init()
      end

      @impl Homex.Entity.Switch
      def set_on(%Entity{} = entity) do
        Entity.put_change(entity, :state, @on_payload)
      end

      @impl Homex.Entity.Switch
      def set_off(%Entity{} = entity) do
        Entity.put_change(entity, :state, @off_payload)
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

      def handle_info({other_topic, _payload}, entity) when is_binary(other_topic) do
        {:noreply, entity}
      end

      def handle_info(:update, entity) do
        entity
        |> handle_timer()
        |> Entity.execute_from_handle_info(entity)
      end

      @impl Homex.Entity.Switch
      def handle_init(entity), do: entity

      @impl Homex.Entity.Switch
      def handle_timer(entity), do: entity

      @impl Homex.Entity.Switch
      def handle_on(entity), do: entity

      @impl Homex.Entity.Switch
      def handle_off(entity), do: entity

      defoverridable handle_on: 1,
                     handle_off: 1,
                     handle_timer: 1,
                     handle_init: 1
    end
  end
end
