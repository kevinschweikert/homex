defmodule Homex.LivebookTest do
  use Homex.EntityCase, async: false

  import Kino.Test

  defmodule TestSwitch do
    use Homex.Entity.Switch, id: :dash_switch, name: "Dash Switch"
  end

  defmodule TestLight do
    use Homex.Entity.Light, id: :dash_light, name: "Dash Light", modes: [:brightness]
  end

  setup :configure_livebook_bridge

  setup do
    for module <- [TestSwitch, TestLight] do
      {:ok, entity} = Entity.new(module)
      start_supervised!({Entity, entity})
    end

    kino = Homex.Livebook.new()
    cards = connect(kino).devices |> Enum.flat_map(& &1.cards) |> Map.new(&{&1.id, &1})

    %{kino: kino, cards: cards}
  end

  defp command(kino, id, cmd), do: push_event(kino, "command", %{"id" => id, "cmd" => cmd})

  test "a card carries every key the browser expects", %{cards: cards} do
    assert cards["dash_switch"] == %{
             id: "dash_switch",
             name: "Dash Switch",
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

    assert cards["dash_light"].slider == %{field: "brightness"}
  end

  test "a command reaches the entity, and an unknown field is ignored", %{kino: kino} do
    command(kino, "dash_switch", %{"state" => true, "not-a-field" => 1})

    assert_receive {:homex, :state, %Descriptor{id: :dash_switch}, _, %{state: true}}
    assert Process.alive?(kino.pid)
  end

  test "brightness is clamped before it reaches the entity", %{kino: kino} do
    command(kino, "dash_light", %{"brightness" => 500})

    assert_receive {:homex, :state, %Descriptor{id: :dash_light}, _, %{brightness: 100}}
  end

  test "a command for an unknown entity is ignored", %{kino: kino} do
    command(kino, "no-such-entity", %{"state" => true})

    assert Process.alive?(kino.pid)
  end
end
