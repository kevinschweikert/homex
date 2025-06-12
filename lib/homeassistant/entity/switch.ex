defmodule Homeassistant.Entity.Switch do
  @moduledoc """
  https://www.home-assistant.io/integrations/switch.mqtt
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      @name opts[:name]
      @state_topic "homeassistant/switch/#{Homeassistant.entity_id(@name)}"
      @command_topic "homeassistant/switch/#{Homeassistant.entity_id(@name)}/set"
      @on_payload "ON"
      @off_payload "OFF"

      use GenServer

      def start_link(init_arg) do
        GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
      end

      def entity_id do
        Homeassistant.entity_id(@name)
      end

      def state_topic() do
        @state_topic
      end

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
        {:ok, %{}}
      end

      @impl GenServer
      def handle_info({@state_topic, @on_payload}, state) do
        handle_on(state)
      end

      def handle_info({@state_topic, @off_payload}, state) do
        handle_off(state)
      end

      def handle_info({@state_topic, payload}, state) do
        handle_state(payload, state)
      end

      def handle_info({@command_topic, payload}, state) do
        handle_command(payload, state)
      end

      def handle_on(state) do
        {:noreply, state}
      end

      def handle_off(state) do
        {:noreply, state}
      end

      def handle_state(payload, state) do
        {:noreply, state}
      end

      def handle_command(_payload, state) do
        {:noreply, state}
      end

      defoverridable handle_on: 1, handle_off: 1, handle_state: 2, handle_command: 2
    end
  end
end
