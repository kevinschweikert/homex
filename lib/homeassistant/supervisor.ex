defmodule Homeassistant.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    {name, rest} = Keyword.pop(init_arg, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, rest, name: name)
  end

  @impl Supervisor
  def init(opts \\ []) do
    children = [
      {DynamicSupervisor, name: Homeassistant.EntitySupervisor, strategy: :one_for_one},
      {Homeassistant.Manager, opts}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end
end
