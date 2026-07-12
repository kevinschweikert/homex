defmodule Homex.Adapter.Test do
  @moduledoc """
  A `Homex.Adapter` for tests.

  Forwards every `publish_state/3` as `{:publish_state, descriptor, changes}`
  and every `entities_changed/1` as `:entities_changed` to the attached process:

      Homex.Adapter.Test.attach()

      Homex.Entity.send_command("my-switch", %{state: true})
      assert_receive {:publish_state, %Homex.Descriptor{}, %{state: true}}
  """
  @behaviour Homex.Adapter

  def start_link(_opts \\ []), do: Agent.start_link(fn -> MapSet.new() end, name: __MODULE__)

  @impl Homex.Adapter
  def child_spec(opts), do: %{id: __MODULE__, start: {__MODULE__, :start_link, [opts]}}

  @doc """
  Attaches a process to receive `{:publish_state, descriptor, changes}` messages
  from entities started under it (matched via `$ancestors`, so async tests
  don't see each other's messages).
  """
  def attach(pid \\ self()) do
    Agent.update(__MODULE__, fn pids ->
      pids |> MapSet.put(pid) |> MapSet.filter(&Process.alive?/1)
    end)
  end

  @impl Homex.Adapter
  def publish_state(_instance, descriptor, changes) do
    notify_attached({:publish_state, descriptor, changes})
  end

  @impl Homex.Adapter
  def entities_changed(_instance), do: notify_attached(:entities_changed)

  # delivers to the attached process in the caller's supervision ancestry
  defp notify_attached(message) do
    attached = Agent.get(__MODULE__, & &1)

    ancestors =
      Process.get(:"$ancestors", [])
      |> Enum.map(fn
        pid when is_pid(pid) -> pid
        name -> Process.whereis(name)
      end)

    with pid when is_pid(pid) <- Enum.find([self() | ancestors], &MapSet.member?(attached, &1)) do
      send(pid, message)
    end

    :ok
  end
end
