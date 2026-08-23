defmodule Homex.Adapter.ESPHome.Button do
  @moduledoc false

  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform

  @behaviour Platform

  @impl Platform
  def list_entity(%{options: options}) do
    %Proto.ListEntitiesButtonResponse{
      device_class: options.device_class,
      disabled_by_default: not options.enabled_by_default
    }
  end

  # the press is the request itself, so the native API has no state frame for a
  # button — its `attrs` field has no counterpart here either
  @impl Platform
  def state(_descriptor, _values), do: nil

  @impl Platform
  def command(%Proto.ButtonCommandRequest{}), do: %{pressed: true}
  def command(_request), do: nil
end
