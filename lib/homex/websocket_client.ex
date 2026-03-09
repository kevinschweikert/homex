defmodule Homex.WebsocketClient do
  use WebSockex
  require Logger

  @spec start_link(Keyword.t()) :: {:ok, pid()} | {:error, term()}
  def start_link(args) do
    url = url(Keyword.fetch!(args, :host), Keyword.get(args, :port, 8123))

    WebSockex.start_link(
      url,
      __MODULE__,
      %{token: Keyword.fetch!(args, :token), url: url, last_id: 0},
      name: __MODULE__
    )
  end

  @spec send(atom(), map()) :: :ok
  def send(type \\ :text, %{} = msg), do: WebSockex.cast(__MODULE__, {:send, {type, msg}})

  @impl true
  def handle_cast({:send, {type, %{} = msg}}, state) do
    msg_id = state.last_id + 1
    msg = Map.put(msg, :id, msg_id)
    IO.puts("Sending #{type} frame with payload: #{inspect(msg)}")
    {:reply, {type, Jason.encode!(msg)}, %{state | last_id: msg_id}}
  end

  @impl true
  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, msg} ->
        # dbg(msg, limit: :infinity)
        handle_msg(msg, state)

      {:error, error} ->
        Logger.warning("Couldn't decode message `#{inspect(error)}`:\n#{inspect(msg)}")
        {:ok, state}
    end
  end

  @impl true
  def handle_disconnect(%{reason: reason}, state) do
    Logger.warning("WebSocket disconnected, attempting reconnect: #{inspect(reason)}")
    {:reconnect, state}
  end

  def handle_msg(%{"type" => "auth_required"}, %{token: token} = state) do
    reply = Jason.encode!(%{type: "auth", access_token: token})
    {:reply, {:text, reply}, state}
  end

  def handle_msg(%{"type" => "auth_ok"}, state) do
    msg_id = state.last_id + 1
    reply = Jason.encode!(%{id: msg_id, type: :subscribe_events, event_type: :state_changed})
    {:reply, {:text, reply}, %{state | last_id: msg_id}}
  end

  def handle_msg(%{"type" => "event", "event" => event}, state) do
    payload = %{
      entity_id: event["data"]["entity_id"],
      new_state: event["data"]["new_state"],
      old_state: event["data"]["old_state"]
    }

    dispatch("state_changed", payload)
    {:ok, state}
  end

  def handle_msg(%{"type" => "result", "result" => results}, state) when is_list(results) do
    Enum.each(
      results,
      &dispatch("state_current", %{
        entity_id: &1["entity_id"],
        current_state: Map.take(&1, ["attributes", "state", "device_class"])
      })
    )

    {:ok, state}
  end

  def handle_msg(msg, state) do
    Logger.warning("Unhandled message: #{inspect(msg)}")
    {:ok, state}
  end

  def url(host, port) when is_binary(host) and is_integer(port),
    do: "ws://#{host}:#{port}/api/websocket"

  defp dispatch(topic, payload) do
    Registry.dispatch(
      Homex.Websocket.registry_name(),
      topic,
      &for({pid, _} <- &1, do: Kernel.send(pid, {String.to_atom(topic), payload}))
    )
  end
end
