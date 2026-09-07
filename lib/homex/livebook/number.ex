defmodule Homex.Livebook.Number do
  @moduledoc false

  alias Homex.Livebook.Kind

  @behaviour Kind

  @impl Kind
  def card(%{options: options}, %{state: value}, _changes) do
    control =
      if options[:mode] == :slider do
        %{type: :slider, min: options[:min], max: options[:max], step: options[:step]}
      else
        %{
          type: :input,
          kind: :number,
          min: options[:min],
          max: options[:max],
          step: options[:step]
        }
      end

    %{
      icon: "🔢",
      value: Kind.format(value),
      unit: options[:unit_of_measurement],
      sub: options[:device_class] || "number",
      controls: [Map.merge(control, %{field: "state", value: value})]
    }
  end
end
