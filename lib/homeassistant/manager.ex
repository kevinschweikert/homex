defmodule Homeassistant.Manager do
  use GenServer

  alias Homeassistant.Client

  require Logger

  defstruct [
    :emqtt_pid,
    :emqtt_opts,
    connected: false,
    queue: :queue.new(),
    subscriptions: [],
    entities: []
  ]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl GenServer
  def init(init_arg \\ []) do
    emqtt_opts = Keyword.get(init_arg, :emqtt, []) |> Keyword.merge(emqtt_defaults())
    entities = Keyword.get(init_arg, :entities, [])

    {:ok, emqtt_pid} = Client.start_link(emqtt_opts)
    {:ok, _} = Client.connect(emqtt_pid)

    for module <- entities do
      {:ok, _pid} =
        DynamicSupervisor.start_child(Homeassistant.EntitySupervisor, module)

      Logger.info("started entity #{module.entity_id()}")

      for subscription <- module.subscriptions() do
        {:ok, _, _} = Client.subscribe(emqtt_pid, subscription)
        Logger.debug("subscribed to #{subscription}")
      end
    end

    {:ok,
     %__MODULE__{
       entities: entities,
       emqtt_pid: emqtt_pid,
       emqtt_opts: emqtt_opts,
       connected: true
     }}
  end

  @impl GenServer
  def handle_info(
        {:publish, %{topic: topic, payload: payload}},
        %__MODULE__{entities: entities} = state
      ) do
    for module <- entities, do: send(module, {topic, payload})
    {:noreply, state}
  end

  def handle_info({:EXIT, emqtt_pid, reason}, %__MODULE__{emqtt_pid: emqtt_pid} = state) do
    Logger.warning("emqtt crashed #{inspect(reason)}")
    {:noreply, %{state | connected: false, emqtt_pid: nil}}
  end

  def handle_info({:disconnected, _, _}, %__MODULE__{} = state) do
    Logger.warning("emqtt disconnected")
    {:noreply, %{state | connected: false}}
  end

  defp emqtt_defaults do
    [
      name: Homeassistant.EMQTT,
      reconnect: :infinity,
      owner: self(),
      host: ~c"localhost",
      port: 1883,
      username: ~c"admin",
      password: ~c"admin"
    ]
  end
end
