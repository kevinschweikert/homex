defmodule Homeassistant.Entity.Switch do
  @moduledoc """
  https://www.home-assistant.io/integrations/switch.mqtt
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @behaviour Homeassistant.Entity
      @name opts[:name]
      @state_topic "homeassistant/switch/#{Homeassistant.entity_id(@name)}"
      @command_topic "homeassistant/switch/#{Homeassistant.entity_id(@name)}/set"
      @on_payload Keyword.get(opts, :on_payload, "ON")
      @off_payload Keyword.get(opts, :off_payload, "OFF")
      @update_interval Keyword.get(opts, :update_interval, 5000)

      use GenServer

      def start_link(init_arg) do
        GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
      end

      def entity_id do
        Homeassistant.entity_id(@name)
      end

      @impl Homeassistant.Entity
      def subscriptions do
        [@command_topic]
      end

      @impl Homeassistant.Entity
      def state_topic() do
        @state_topic
      end

      @impl Homeassistant.Entity
      def command_topic() do
        @command_topic
      end

      def on_payload() do
        @on_payload
      end

      def off_payload() do
        @off_payload
      end

      @enforce_keys [:name]
      defstruct [
        :device_class,
        :enabled_by_default,
        :entity_category,
        :entity_picture,
        :icon,
        :name,
        :qos,
        :retain
      ]

      @impl GenServer
      def init(_init_arg \\ []) do
        :timer.send_interval(@update_interval, :update)
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

      @impl Homeassistant.Entity
      def initial_state() do
        %{}
      end

      @impl Homeassistant.Entity
      def handle_update(state) do
        {:noreply, state}
      end

      @impl Homeassistant.Entity
      def handle_command(_payload, state) do
        {:noreply, state}
      end

      defp maybe_publish({:reply, payload, state}) do
        Homeassistant.publish(@state_topic, payload)
        {:noreply, state}
      end

      defp maybe_publish({:noreply, state}) do
        {:noreply, state}
      end

      defoverridable handle_on: 1,
                     handle_off: 1,
                     handle_command: 2,
                     handle_update: 1,
                     initial_state: 0
    end
  end
end
