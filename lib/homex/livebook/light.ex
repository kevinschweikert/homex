defmodule Homex.Livebook.Light do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @impl Kind
  def card(%{options: %{modes: modes}}, %{state: on?} = values, _changes) do
    brightness = values[:brightness]

    %{
      icon: "💡",
      value: Kind.onoff(on?),
      on: on?,
      brightness: brightness,
      sub: if(brightness, do: "brightness #{round(brightness)}%", else: "light"),
      toggle: %{field: "state"},
      slider: if(:brightness in modes, do: %{field: "brightness"})
    }
  end
end
