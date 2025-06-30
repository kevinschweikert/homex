defmodule Homex.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    {name, rest} = Keyword.pop(init_arg, :name, __MODULE__)
    Supervisor.start_link(__MODULE__, rest, name: name)
  end

  @impl Supervisor
  def init(opts \\ []) do
    children = [
      {DynamicSupervisor, name: Homex.EntitySupervisor, strategy: :one_for_one},
      {Homex.Manager, opts}
    ]

    opts = [strategy: :one_for_one, name: __MODULE__]
    Supervisor.init(children, opts)
  end
end
