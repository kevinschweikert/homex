defmodule Homex.Livebook.Light do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @impl Kind
  def card(%{options: %{modes: modes}}, %{state: on?} = values, _changes) do
    brightness = values[:brightness]

    slider =
      if :brightness in modes,
        do: %{type: :slider, field: "brightness", value: brightness, min: 0, max: 100, step: 1}

    %{
      icon: "💡",
      value: Kind.onoff(on?),
      on: on?,
      brightness: brightness,
      sub: if(brightness, do: "brightness #{round(brightness)}%", else: "light"),
      controls: [%{type: :toggle, field: "state"}, slider] |> Enum.reject(&is_nil/1)
    }
  end
end
