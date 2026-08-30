defmodule Homex.Adapter.ESPHome.Number do
  @moduledoc false

  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform

  @behaviour Platform

  @impl Platform
  def list_entity(%{options: options}) do
    %Proto.ListEntitiesNumberResponse{
      min_value: options.min,
      max_value: options.max,
      step: options.step,
      mode: mode(options.mode),
      unit_of_measurement: options.unit_of_measurement,
      device_class: options.device_class,
      disabled_by_default: not options.enabled_by_default
    }
  end

  # a number that has not been set yet reads as unknown in Home Assistant rather
  # than as the zero the proto field would otherwise carry
  @impl Platform
  def state(_descriptor, %{state: nil}), do: %Proto.NumberStateResponse{missing_state: true}
  def state(_descriptor, %{state: state}), do: %Proto.NumberStateResponse{state: state}

  @impl Platform
  def command(%Proto.NumberCommandRequest{state: state}), do: %{state: state}
  def command(_request), do: nil

  defp mode(:auto), do: :NUMBER_MODE_AUTO
  defp mode(:box), do: :NUMBER_MODE_BOX
  defp mode(:slider), do: :NUMBER_MODE_SLIDER
end
