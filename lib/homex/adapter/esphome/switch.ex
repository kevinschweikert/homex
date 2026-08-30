defmodule Homex.Adapter.ESPHome.Switch do
  @moduledoc false

  alias Espex.Proto
  alias Homex.Adapter.ESPHome.Platform

  @behaviour Platform

  @impl Platform
  def list_entity(_descriptor), do: %Proto.ListEntitiesSwitchResponse{}

  @impl Platform
  def state(_descriptor, %{state: state}), do: %Proto.SwitchStateResponse{state: state}

  @impl Platform
  def command(%Proto.SwitchCommandRequest{state: state}), do: %{state: state}
  def command(_request), do: nil
end
