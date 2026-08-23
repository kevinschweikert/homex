defmodule Homex.Livebook.Kind do
  @moduledoc false

  @defaults %{
    icon: "⬤",
    value: "—",
    unit: nil,
    sub: nil,
    on: false,
    brightness: nil,
    flash: false,
    buttons: [],
    toggle: nil,
    slider: nil
  }

  @typedoc """
  What a kind renders, as far as it differs from `#{inspect(Map.keys(@defaults))}`.

  `buttons` is a list of `%{label: String.t(), cmd: map()}`, `toggle` and
  `slider` are `%{field: String.t()}` naming a boolean and a 0..100 field.
  """
  @type card() :: map()

  @doc """
  The card for one entity.

  Gets both the current `values` and the `changes` that just committed, empty on
  the first render. A state field reads from `values`, an event field only ever
  from `changes` — `%{trigger: true}` in `values` means it fired at some point,
  which is nothing to display.
  """
  @callback card(Homex.Descriptor.t(), values :: map(), changes :: map()) :: card()

  @doc "The card payload for one entity, or a bare readout for an unknown kind"
  def card(module, %Homex.Descriptor{} = descriptor, values, changes) do
    @defaults
    |> Map.merge(fields(module, descriptor, values, changes))
    |> Map.put(:name, descriptor.name)
  end

  defp fields(nil, _descriptor, values, _changes), do: %{sub: attributes(values) || "no state"}
  defp fields(_module, _descriptor, nil, _changes), do: %{sub: "no state"}
  defp fields(module, descriptor, values, changes), do: module.card(descriptor, values, changes)

  @doc "Renders a value the way a readout should look"
  def format(nil), do: "—"
  def format(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 1)
  def format(value) when is_number(value), do: to_string(value)
  def format(value), do: inspect(value)

  @doc "The readout of a state field"
  def onoff(true), do: "on"
  def onoff(_value), do: "off"

  @doc """
  The readout of an event field: it says `fired` for a moment and clears again,
  because an event has no state to sit in.
  """
  def fired(true, sub), do: %{value: "fired", on: true, flash: true, sub: sub}
  def fired(_fired, sub), do: %{sub: sub}

  @doc "Attributes as a single line, or `nil` when there are none"
  def attributes(attrs) when is_map(attrs) and map_size(attrs) > 0 do
    Enum.map_join(attrs, " · ", fn {key, value} -> "#{key}: #{inspect(value)}" end)
  end

  def attributes(_attrs), do: nil
end
