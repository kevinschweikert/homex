defmodule Homex.LivebookTest do
  use Homex.EntityCase, async: false

  import Kino.Test

  defmodule TestSwitch do
    use Homex.Entity.Switch, name: "dash-switch"
  end

  defmodule TestLight do
    use Homex.Entity.Light, name: "dash-light", modes: [:brightness]
  end

  setup :configure_livebook_bridge

  setup do
    for module <- [TestSwitch, TestLight] do
      {:ok, entity} = Entity.new(module)
      start_supervised!({Entity, entity})
    end

    kino = Homex.Livebook.new()
    cards = connect(kino).devices |> Enum.flat_map(& &1.cards) |> Map.new(&{&1.name, &1})

    %{kino: kino, cards: cards}
  end

  defp command(kino, name, cmd), do: push_event(kino, "command", %{"name" => name, "cmd" => cmd})

  test "a card carries every key the browser expects", %{cards: cards} do
    assert cards["dash-switch"] == %{
             name: "dash-switch",
             icon: "🔌",
             value: "off",
             unit: nil,
             sub: "switch",
             on: false,
             brightness: nil,
             flash: false,
             buttons: [],
             toggle: %{field: "state"},
             slider: nil
           }

    assert cards["dash-light"].slider == %{field: "brightness"}
  end

  test "a command reaches the entity, and an unknown field is ignored", %{kino: kino} do
    command(kino, "dash-switch", %{"state" => true, "not-a-field" => 1})

    assert_receive {:homex, :state, %Descriptor{name: "dash-switch"}, _, %{state: true}}
    assert Process.alive?(kino.pid)
  end

  test "brightness is clamped before it reaches the entity", %{kino: kino} do
    command(kino, "dash-light", %{"brightness" => 500})

    assert_receive {:homex, :state, %Descriptor{name: "dash-light"}, _, %{brightness: 100}}
  end

  test "a command for an unknown entity is ignored", %{kino: kino} do
    command(kino, "no-such-entity", %{"state" => true})

    assert Process.alive?(kino.pid)
  end
end
