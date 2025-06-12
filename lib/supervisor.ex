defmodule Homeassistant.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl Supervisor
  def init(init_arg \\ []) do
    emqtt_opts =
      Keyword.get(init_arg, :emqtt, [])

    entities = Keyword.get(init_arg, :entities, [])

    children = [
      {DynamicSupervisor, name: Homeassistant.EntitySupervisor, strategy: :one_for_one},
      {DynamicSupervisor, name: Homeassistant.MQTTSupervisor, strategy: :one_for_one},
      {Homeassistant.Manager, [emqtt: emqtt_opts, entities: entities]}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end
end
