defmodule Homex.Entity.Switch do
  @moduledoc """
  https://www.home-assistant.io/integrations/switch.mqtt
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts], generated: true do
      @behaviour Homex.Entity

      @name opts[:name]
      @platform "switch"
      @entity_id Homex.entity_id(@name)
      @unique_id Homex.unique_id(@platform, @name)
      @state_topic "homex/#{@platform}/#{@entity_id}"
      @command_topic "homex/#{@platform}/#{@entity_id}/set"
      @on_payload Keyword.get(opts, :on_payload, "ON")
      @off_payload Keyword.get(opts, :off_payload, "OFF")
      @update_interval Keyword.get(opts, :update_interval, :never)

      use GenServer

      def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

      @impl Homex.Entity
      def entity_id, do: @entity_id

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def subscriptions, do: [@command_topic]

      @impl Homex.Entity
      def state_topic(), do: @state_topic

      @impl Homex.Entity
      def command_topic(), do: @command_topic

      @impl Homex.Entity
      def platform(), do: @platform

      def on(), do: @on_payload
      def off(), do: @off_payload

      @impl Homex.Entity
      def config do
        %{
          platform: @platform,
          state_topic: @state_topic,
          command_topic: @command_topic,
          name: @entity_id,
          unique_id: @unique_id
        }
      end

      @impl GenServer
      def init(_init_arg \\ []) do
        case @update_interval do
          :never -> :ok
          time -> :timer.send_interval(time, :update)
        end

        {:ok, initial_state()}
      end

      @impl GenServer
      def handle_info({@command_topic, @on_payload}, state) do
        handle_on(state)
        |> maybe_publish()
      end

      def handle_info({@command_topic, @off_payload}, state) do
        handle_off(state)
        |> maybe_publish()
      end

      def handle_info({@command_topic, payload}, state) do
        handle_command(payload, state)
        |> maybe_publish()
      end

      def handle_info({_other_topic, _payload}, state) do
        {:noreply, state}
      end

      def handle_info(:update, state) do
        handle_update(state)
        |> maybe_publish()
      end

      def handle_on(state) do
        {:noreply, state}
      end

      def handle_off(state) do
        {:noreply, state}
      end

      @impl Homex.Entity
      def initial_state() do
        %{}
      end

      @impl Homex.Entity
      def handle_update(state) do
        {:noreply, state}
      end

      @impl Homex.Entity
      def handle_command(_payload, state) do
        {:noreply, state}
      end

      defp maybe_publish({:reply, messages, state}) do
        for {topic_atom, payload} <- messages do
          topic_atom
          |> atom_to_topic()
          |> Homex.publish(payload)
        end

        {:noreply, state}
      end

      defp maybe_publish({:noreply, state}) do
        {:noreply, state}
      end

      defp atom_to_topic(:state), do: @state_topic

      defoverridable handle_on: 1,
                     handle_off: 1,
                     handle_command: 2,
                     handle_update: 1,
                     initial_state: 0
    end
  end
end
