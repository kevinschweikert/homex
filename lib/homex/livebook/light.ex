defmodule Homex.Livebook.Light do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @impl Kind
  def card(%{options: %{modes: modes}}, %{state: on?} = values, _changes) do
    # the browser works in percent, the entity in 0..1
    percent = values[:brightness] && values[:brightness] * 100

    slider =
      if :brightness in modes,
        do: %{type: :slider, field: "brightness", value: percent, min: 0, max: 100, step: 1}

    %{
      icon: "💡",
      value: Kind.onoff(on?),
      on: on?,
      brightness: percent,
      sub: if(percent, do: "brightness #{round(percent)}%", else: "light"),
      controls: [%{type: :toggle, field: "state"}, slider] |> Enum.reject(&is_nil/1)
    }
  end
end
