defmodule Homex.Livebook.Button do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @impl Kind
  def card(_descriptor, _values, changes) do
    %{icon: "🔘", buttons: [%{label: "Press", cmd: %{pressed: true}}]}
    |> Map.merge(Kind.fired(changes[:pressed], "button"))
  end
end
