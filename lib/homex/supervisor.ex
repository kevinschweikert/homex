defmodule Homex.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    {name, rest} = Keyword.pop(init_arg, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, rest, name: name)
  end

  @impl Supervisor
  def init(opts \\ []) do
    entities = Homex.entities()

    children = [
      {DynamicSupervisor, name: Homex.EntitySupervisor, strategy: :one_for_one},
      {Homex.Manager, opts},
      {Task, fn -> start_entities(entities) end}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end

  defp start_entities(entities) do
    for entity <- entities do
      Homex.Manager.add_entity(entity)
    end
  end
end
