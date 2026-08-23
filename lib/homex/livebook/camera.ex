defmodule Homex.Livebook.Camera do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @icon "📷"

  @impl Kind
  def card(_descriptor, %{image: image} = values, _changes) when is_binary(image) do
    %{
      icon: @icon,
      value: "#{div(byte_size(image), 1024)} kB",
      sub: Kind.attributes(values[:attrs]) || "camera"
    }
  end

  def card(_descriptor, values, _changes),
    do: %{icon: @icon, sub: Kind.attributes(values[:attrs]) || "waiting for a snapshot"}
end
