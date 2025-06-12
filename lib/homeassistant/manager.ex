defmodule Homeassistant.Manager do
  use GenServer

  alias Homeassistant.Client

  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl GenServer
  def init(init_arg \\ []) do
    emqtt_opts =
      Keyword.get(init_arg, :emqtt, [])
      |> Keyword.drop([:name])
      |> Keyword.merge(emqtt_defaults())

    entities = Keyword.get(init_arg, :entities, [])

    {:ok, _} =
      DynamicSupervisor.start_child(Homeassistant.MQTTSupervisor, %{
        id: :emqtt,
        start: {:emqtt, :start_link, [emqtt_opts]}
      })

    {:ok, _} = Client.connect()

    for module <- entities do
      {:ok, _pid} =
        DynamicSupervisor.start_child(Homeassistant.EntitySupervisor, module)

      {:ok, _, _} = Client.subscribe(module.state_topic())
      {:ok, _, _} = Client.subscribe(module.command_topic())
    end

    {:ok, %{entities: entities}}
  end

  @impl GenServer
  def handle_info({:publish, %{topic: topic, payload: payload}}, %{entities: entities} = state) do
    for module <- entities, do: send(module, {topic, payload})
    {:noreply, state}
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
