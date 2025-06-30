defmodule Homeassistant do
  @moduledoc """
  Documentation for `Homeassistant`.
  """

  defdelegate start_link(opts), to: Homeassistant.Supervisor
  defdelegate publish(topic, payload), to: Homeassistant.Manager
  defdelegate subscribe(topic), to: Homeassistant.Manager

  def unique_id(name) do
    "#{entity_id(name)}_#{:erlang.phash2(name)}"
  end

  def entity_id(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]/, "_")
  end
end
