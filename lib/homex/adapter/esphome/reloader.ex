defmodule Homex.Adapter.ESPHome.Reloader do
  @moduledoc false

  # TODO: delete this module once espex can update the device config and
  # disconnect clients on a running server. Restarting the tree is the only way
  # to apply a change today.

  defstruct [:supervisor, :timer_ref]
  @debounce_interval 1_000

  use GenServer

  require Logger

  alias Homex.Adapter.ESPHome.EspexTree

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @impl GenServer
  def init(opts) do
    Homex.subscribe()
    supervisor = Keyword.fetch!(opts, :supervisor)
    {:ok, %__MODULE__{supervisor: supervisor, timer_ref: nil}}
  end

  @impl GenServer
  def handle_info({:homex, :devices_changed}, state) do
    timer_ref = refresh_timer(state)
    {:noreply, %{state | timer_ref: timer_ref}}
  end

  def handle_info({:homex, :entities_changed}, state) do
    timer_ref = refresh_timer(state)
    {:noreply, %{state | timer_ref: timer_ref}}
  end

  def handle_info(:restart_espex_tree, state) do
    restart_espex_tree(state)
    {:noreply, state}
  end

  def handle_info(_msg, state), do: {:noreply, state}

  def refresh_timer(%__MODULE__{timer_ref: timer_ref}) do
    if timer_ref, do: Process.cancel_timer(timer_ref)
    Process.send_after(self(), :restart_espex_tree, @debounce_interval)
  end

  defp restart_espex_tree(state) do
    with :ok <- Supervisor.terminate_child(state.supervisor, EspexTree),
         {:ok, _pid} <- Supervisor.restart_child(state.supervisor, EspexTree) do
      Logger.debug("Reloaded the ESPHome adapter")
    else
      {:error, reason} ->
        Logger.error("could not reload the ESPHome adapter: #{inspect(reason)}")
    end
  end
end
