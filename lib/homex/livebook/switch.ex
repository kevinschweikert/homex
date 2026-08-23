defmodule Homex.Livebook.Switch do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @impl Kind
  def card(_descriptor, %{state: on?}, _changes),
    do: %{icon: "🔌", value: Kind.onoff(on?), on: on?, sub: "switch", toggle: %{field: "state"}}
end
