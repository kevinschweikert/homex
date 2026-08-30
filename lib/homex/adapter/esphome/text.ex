defmodule Homex.Adapter.ESPHome.Text do
  @moduledoc false

  alias Homex.Descriptor
  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform

  @behaviour Platform

  @impl Platform
  def list_entity(%Descriptor{options: options}),
    do: %Proto.ListEntitiesTextResponse{
      mode: mode(options.mode),
      min_length: options.min,
      max_length: options.max,
      pattern: options.pattern,
      disabled_by_default: not options.enabled_by_default
    }

  # a text entity that has not been set yet reads as unknown in Home Assistant
  # rather than as the empty string the proto field would otherwise carry
  @impl Platform
  def state(_descriptor, %{state: nil}), do: %Proto.TextStateResponse{missing_state: true}
  def state(_descriptor, %{state: state}), do: %Proto.TextStateResponse{state: state}

  @impl Platform
  def command(%Proto.TextCommandRequest{state: state}), do: %{state: state}
  def command(_request), do: nil

  defp mode(:text), do: :TEXT_MODE_TEXT
  defp mode(:password), do: :TEXT_MODE_PASSWORD
end
