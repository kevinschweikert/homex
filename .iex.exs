defmodule MySwitch do
  use Homeassistant.Entity.Switch, name: "my-switch"

  def handle_on(state) do
    IO.puts("Switch turned on")
    {:noreply, state}
  end

  def handle_off(state) do
    IO.puts("Switch turned off")
    {:noreply, state}
  end

  def handle_update(state) do
    {:reply, Enum.random(["ON", "OFF"]), state}
  end
end
