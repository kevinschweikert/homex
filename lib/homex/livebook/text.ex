defmodule Homex.Livebook.Text do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @impl Kind
  def card(%{options: options}, %{state: text}, _changes) do
    %{
      icon: "📝",
      value: Kind.format(text),
      sub: "text",
      controls: [
        %{
          type: :input,
          field: "state",
          value: text,
          kind: if(options[:mode] == :password, do: :password, else: :text),
          maxlength: options[:max]
        }
      ]
    }
  end
end
