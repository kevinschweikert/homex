defmodule Homex.Livebook.DeviceTrigger do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @impl Kind
  def card(_descriptor, _values, changes) do
    %{icon: "⚡", buttons: [%{label: "Trigger", cmd: %{trigger: true}}]}
    |> Map.merge(Kind.fired(changes[:trigger], "device trigger"))
  end
end
