defmodule Homex.Websocket do
  @registry_name Homex.WebsocketRegistry
  @moduledoc """
  WebSocket client for the [Home Assistant WebSocket API](https://developers.home-assistant.io/docs/api/websocket).

  Establishes and maintains a persistent WebSocket connection via the WebsocketClient module
  to a Home Assistant instance. On connection, it authenticates using a long-lived access
  token and subscribes to `state_changed` events. Incoming state change events are dispatched
  via a `Registry` named `#{@registry_name}`.

  The `#{@registry_name}` instance is started with the `Homex` supervisor.

  This module is intended to be started under a supervision tree, typically as part
  of the application's main supervisor.

  ## Example

      def start(_type, _args) do
        children =
          [
            ...,
            {Homex.Websocket,
              token: Application.get_env(:my_app, :home_assistant_access_token),
              host: Application.get_env(:my_app, :home_assistant_host),
              port: Application.get_env(:my_app, :home_assistant_port, 8123)}
          ]

        opts = [strategy: :one_for_one, name: MyApp.Supervisor]
        Supervisor.start_link(children, opts)
      end

  ## Example GenServers that subscribe to WebSocket Registry events

      defmodule MyApp.HomexHandler do
        use GenServer
        require Logger

        def start_link(__opts) do
          GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
        end

        @impl true
        def init(state) do
          Homex.WebsocketClient.register("state_changed")
          {:ok, state}
        end

        @entity_id "some.entity"
        @impl GenServer
        # Handle a specific entity by its id
        def handle_info(
              {:state_changed, %{entity_id: @entity_id, new_state: new_state}},
              state
            ) do
          Logger.debug("Got new state for " <> @entity_id)
          {:noreply, state}
        end

        def handle_info(event, state) do
          Logger.debug("Unhandled event")
          {:noreply, state}
        end
      end

  ## Registry events

  Once authenticated, the client dispatches the following messages via `Homex.WebsocketClient.registry_name/0`:

    * `{:state_changed, %{entity_id: String.t(), new_state: map(), old_state: map()}}` —
      dispatched on the `"state_changed"` topic whenever a Home Assistant entity changes state.

    * `{:state_current, %{entity_id: String.t(), current_state: map()}}` —
      dispatched on the `"state_current"` topic per result. This is triggered
      by calling `Homex.WebsocketClient.get_states/0`.

  Use `register/2` to subscribe the calling process to a topic.
  """
  use GenServer
  require Logger

  alias Homex.WebsocketClient

  @doc """
  Sends a message over the WebSocket connection.

  Casts a message to the Websockex connection, encoding it as JSON.
  A monotonically increasing `:id` field is automatically added to
  each outgoing message.

  ## Arguments

    * `type` — the WebSocket frame type. Defaults to `:text`. See `WebSockex`
      for supported frame types.

    * `msg` — a map representing the message payload. Must include a `"type"`
      key matching a [Home Assistant WebSocket command](https://developers.home-assistant.io/docs/api/websocket/#command-phase).

  ## Examples

      iex> Homex.WebsocketClient.send(%{type: "get_states"})

      iex> Homex.WebsocketClient.send(%{
      ...>   type: "call_service",
      ...>   domain: "light",
      ...>   service: "turn_on",
      ...>   service_data: %{entity_id: "light.living_room"}
      ...> })
  """
  defdelegate send(type \\ :text, msg), to: WebsocketClient

  @doc """
  Starts the WebSocket client and links it to the calling process.

  Connects to the Home Assistant WebSocket API at `ws://<host>:<port>/api/websocket`
  and registers the process under the name `Homex.WebsocketClient`.

  ## Args

  The `args` argument is a keyword list with the following keys:

    * `:host` — **(required)** the hostname or IP address of the Home Assistant instance.

    * `:token` — **(required)** a long-lived access token used to authenticate with
      the Home Assistant WebSocket API. Tokens can be generated from the Home Assistant
      profile page under *Long-Lived Access Tokens*.

    * `:port` — **(optional)** the port Home Assistant is listening on. Defaults to `8123`.
  """
  def start_link(args) do
    GenServer.start_link(__MODULE__, args, name: __MODULE__)
  end

  @impl GenServer
  def init(args) do
    {:ok, %{pid: nil, conn_args: args}, {:continue, :connect}}
  end

  @impl GenServer
  def handle_continue(:connect, %{conn_args: conn_args} = state) do
    with {:ok, pid} <- WebsocketClient.start_link(conn_args) do
      Logger.debug("WS Connected")

      {:noreply, %{state | pid: pid}}
    else
      {:error, reason} ->
        Logger.error("Failed to connect to WS HomeAssistant: #{inspect(reason)}")
        Process.send_after(self(), :reconnect, 5000)
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info(:reconnect, state) do
    {:noreply, state, {:continue, :connect}}
  end

  @registry_topics ["state_changed", "state_current"]
  def registry_name, do: @registry_name
  def registry_topic, do: "homex_websocket_client"

  @doc """
  Registers the calling process to receive dispatched messages for the given topic.

  The `topic` must be one of `"state_changed"` or `"state_current"`. Once registered,
  the process will receive messages of the form `{:state_changed, payload}` or
  `{:state_current, payload}` respectively.

  ## Example

      Homex.Websocket.register("state_changed")
  """
  def register(topic, opts \\ []) when topic in @registry_topics,
    do: Registry.register(registry_name(), topic, opts)

  @doc """
  Requests the list of all registered services from Home Assistant.

  Sends a `get_services` command over the WebSocket connection. The response
  is handled asynchronously via `handle_msg/2` and currently logged as an
  unhandled result.
  """
  @spec get_services() :: :ok
  def get_services, do: send(%{type: "get_services"})

  @doc """
  Requests the current state of all entities from Home Assistant.

  Sends a `get_states` command over the WebSocket connection. The response
  is handled asynchronously — each entity in the result list is dispatched
  individually via `#{@registry_name}` on the `"state_current"` topic as:

      {:state_current, %{entity_id: String.t(), current_state: map()}}

  ## Example

      iex> Homex.WebsocketClient.register("state_current")
      iex> Homex.WebsocketClient.get_states()
      iex> receive do
      ...>   {:state_current, %{entity_id: entity_id, current_state: current_state}} ->
      ...>     IO.puts("\#{entity_id} is \#{inspect(current_state)}")
      ...> end
  """
  @spec get_states() :: :ok
  def get_states, do: send(%{type: "get_states"})
end
