defmodule Homex.Livebook.Select do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @impl Kind
  def card(%{options: options}, %{state: option}, _changes) do
    %{
      icon: "📋",
      value: Kind.format(option),
      sub: "select",
      controls: [
        %{type: :select, field: "state", value: option, options: options[:options]}
      ]
    }
  end
end
