defmodule Homex.Entity do
  @type state() :: term()

  @callback subscriptions() :: [String.t()]
  @callback state_topic() :: String.t()
  @callback command_topic() :: String.t()
  @callback config() :: map()

  @callback initial_state() :: state()
  @callback handle_update(state()) :: {:noreply, state()} | {:reply, Keyword.t(), state()}
  @callback handle_command(String.t(), state()) ::
              {:noreply, state()} | {:reply, Keyword.t(), state()}

  @optional_callbacks command_topic: 0, handle_command: 2

  def implements_behaviour?(module) when is_atom(module) do
    attrs = module.__info__(:attributes) |> Keyword.get_values(:behaviour) |> List.flatten()
    __MODULE__ in attrs
  end
end
