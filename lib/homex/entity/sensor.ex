defmodule Homex.Entity.Sensor do
  @moduledoc """
  https://www.home-assistant.io/integrations/sensor.mqtt/

  Available device classes: https://www.home-assistant.io/integrations/sensor#device-class
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts], generated: true do
      @behaviour Homex.Entity

      @name opts[:name]
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
      def state_topic(), do: @state_topic

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
        :timer.send_interval(@update_interval, :update)
        {:ok, initial_state()}
      end

      @impl GenServer
      def handle_info({_other_topic, _payload}, state) do
        {:noreply, state}
      end

      def handle_info(:update, state) do
        handle_update(state)
        |> maybe_publish()
      end

      @impl Homex.Entity
      def initial_state() do
        %{}
      end

      @impl Homex.Entity
      def handle_update(state) do
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

      defoverridable handle_update: 1, initial_state: 0
    end
  end
end
