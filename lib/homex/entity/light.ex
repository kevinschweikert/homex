defmodule Homex.Entity.Light do
  @moduledoc """
  https://www.home-assistant.io/integrations/light.mqtt/
  """

  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts], generated: true do
      @behaviour Homex.Entity

      @name opts[:name]
      @platform "light"
      @entity_id Homex.entity_id(@name)
      @unique_id Homex.unique_id(@platform, @name)
      @state_topic "homex/#{@platform}/#{@entity_id}"
      @command_topic "homex/#{@platform}/#{@entity_id}/set"
      @brightness_state_topic "homex/#{@platform}/#{@entity_id}/brightness"
      @brightness_command_topic "homex/#{@platform}/#{@entity_id}/brightness/set"
      @update_interval Keyword.get(opts, :update_interval, 5000)
      @unit_of_measurement opts[:unit_of_measurement]
      @on_payload Keyword.get(opts, :on_payload, "ON")
      @off_payload Keyword.get(opts, :off_payload, "OFF")
      @device_class opts[:device_class]

      use GenServer

      def start_link(init_arg), do: GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)

      @impl Homex.Entity
      def entity_id, do: @entity_id

      @impl Homex.Entity
      def unique_id, do: @unique_id

      @impl Homex.Entity
      def subscriptions, do: [@command_topic, @brightness_command_topic]

      @impl Homex.Entity
      def state_topic(), do: @state_topic

      @impl Homex.Entity
      def command_topic(), do: @command_topic

      @impl Homex.Entity
      def platform(), do: @platform

      def brightness_state_topic, do: @brightness_state_topic
      def brightness_command_topic, do: @brightness_command_topic

      def on(), do: @on_payload
      def off(), do: @off_payload

      @doc "converts a string representing an 8-bit value to a percentage from 0 to 100"
      def convert_brightness(brightness, precision \\ 2) when is_binary(brightness) do
        with {value, ""} when value >= 0 and value <= 255 <- Integer.parse(brightness) do
          percentage = value * 100 / 255
          {:ok, Float.round(percentage, precision)}
        else
          _ -> {:error, :invalid_brightness}
        end
      end

      @impl Homex.Entity
      def config do
        %{
          platform: @platform,
          state_topic: @state_topic,
          command_topic: @command_topic,
          brightness_state_topic: @brightness_state_topic,
          brightness_command_topic: @brightness_command_topic,
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
      def handle_info({@command_topic, @on_payload}, state) do
        handle_on(state)
        |> maybe_publish()
      end

      def handle_info({@command_topic, @off_payload}, state) do
        handle_off(state)
        |> maybe_publish()
      end

      def handle_info({@brightness_command_topic, brightness}, state) do
        handle_brightness(brightness, state)
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
        {:reply, [state: on()], state}
      end

      def handle_off(state) do
        {:reply, [state: off()], state}
      end

      def handle_brightness(brightness, state) do
        {:reply, [brightness: brightness], state}
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
      defp atom_to_topic(:brightness), do: @brightness_state_topic

      defoverridable handle_on: 1,
                     handle_off: 1,
                     handle_brightness: 2,
                     handle_command: 2,
                     handle_update: 1,
                     initial_state: 0
    end
  end
end
