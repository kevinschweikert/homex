defmodule Homex.Manager do
  use GenServer

  require Logger

  defstruct [
    :emqtt_pid,
    :emqtt_opts,
    connected: false,
    subscriptions: [],
    entities: [],
    config: %{}
  ]

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def publish(topic, payload)

  def publish(topic, payload) when is_binary(payload) do
    do_publish(topic, payload)
  end

  def publish(topic, payload) do
    with {:ok, payload} <- Jason.encode(payload) do
      do_publish(topic, payload)
    end
  end

  defp do_publish(topic, payload) do
    GenServer.cast(__MODULE__, {:publish, topic, payload})
  end

  def subscribe(topic) do
    GenServer.cast(__MODULE__, {:subscribe, topic})
  end

  @impl GenServer
  def init(init_arg \\ []) do
    emqtt_opts = Keyword.get(init_arg, :emqtt, []) |> Keyword.merge(emqtt_defaults())
    entities = Keyword.get(init_arg, :entities, [])

    {:ok, emqtt_pid} = :emqtt.start_link(emqtt_opts)
    {:ok, _} = :emqtt.connect(emqtt_pid)

    for module <- entities do
      {:ok, _pid} =
        DynamicSupervisor.start_child(Homex.EntitySupervisor, module)

      Logger.info("started entity #{module.entity_id()}")

      for subscription <- module.subscriptions() do
        {:ok, _, _} = :emqtt.subscribe(emqtt_pid, subscription)
        Logger.debug("subscribed to #{subscription}")
      end
    end

    components =
      for module <- entities, into: %{} do
        {module.entity_id(), module.config()}
      end

    config = Homex.config(components)
    payload = Jason.encode!(config)

    :emqtt.publish(
      emqtt_pid,
      "#{Homex.discovery_prefix()}/device/#{Homex.entity_id(config.device.name)}/config",
      payload
    )

    {:ok,
     %__MODULE__{
       entities: entities,
       emqtt_pid: emqtt_pid,
       emqtt_opts: emqtt_opts,
       connected: true,
       config: config
     }}
  end

  @impl GenServer
  def handle_cast(
        {:publish, topic, payload},
        %__MODULE__{emqtt_pid: emqtt_pid, connected: true} = state
      ) do
    :emqtt.publish(emqtt_pid, topic, payload, [])
    {:noreply, state}
  end

  def handle_cast(
        {:subscribe, topic},
        %__MODULE__{emqtt_pid: emqtt_pid, connected: true} = state
      ) do
    :emqtt.subscribe(emqtt_pid, topic)
    {:noreply, state}
  end

  def handle_cast(_, %__MODULE__{connected: false} = state) do
    Logger.error("emqtt not connected!")
    {:noreply, state}
  end

  # new MQTT message from broker
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
      name: Homex.EMQTT,
      reconnect: :infinity,
      owner: self(),
      host: ~c"localhost",
      port: 1883,
      username: ~c"admin",
      password: ~c"admin"
    ]
  end
end
