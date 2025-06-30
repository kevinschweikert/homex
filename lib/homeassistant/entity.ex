defmodule Homeassistant.Entity do
  @type state() :: term()

  @callback subscriptions() :: [String.t()]
  @callback state_topic() :: String.t()
  @callback command_topic() :: String.t()

  @callback initial_state() :: state()
  @callback handle_update(state()) :: {:noreply, state()} | {:reply, String.t(), state()}
  @callback handle_command(String.t(), state()) ::
              {:noreply, state()} | {:reply, String.t(), state()}
end
