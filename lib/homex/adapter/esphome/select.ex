defmodule Homex.Adapter.ESPHome.Select do
  @moduledoc false

  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform

  @behaviour Platform

  @impl Platform
  def list_entity(%{options: options}) do
    %Proto.ListEntitiesSelectResponse{
      options: options.options,
      disabled_by_default: not options.enabled_by_default
    }
  end

  @impl Platform
  def state(_descriptor, %{state: state}), do: %Proto.SelectStateResponse{state: state}

  @impl Platform
  def command(%Proto.SelectCommandRequest{state: state}), do: %{state: state}
  def command(_request), do: nil
end
