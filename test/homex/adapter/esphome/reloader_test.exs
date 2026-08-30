defmodule Homex.Adapter.ESPHome.ReloaderTest do
  # espex calls EntityProvider as a bare module, so only one adapter can run per VM
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias Homex.Adapter.ESPHome
  alias Homex.Adapter.ESPHome.EspexTree

  setup do
    {:ok, sup: start_supervised!({ESPHome, port: 0})}
  end

  defp tree_pid(sup) do
    {EspexTree, pid, _, _} = List.keyfind(Supervisor.which_children(sup), EspexTree, 0)
    pid
  end

  test "a device change restarts the espex tree once in debounce interval", %{sup: sup} do
    before = tree_pid(sup)

    log =
      capture_log(fn ->
        Homex.broadcast({:homex, :devices_changed})
        Homex.broadcast({:homex, :devices_changed})
        Homex.broadcast({:homex, :devices_changed})
        Homex.broadcast({:homex, :devices_changed})
        :timer.sleep(1100)
      end)

    assert log =~ "Reloaded the ESPHome adapter"
    assert tree_pid(sup) != before
  end
end
