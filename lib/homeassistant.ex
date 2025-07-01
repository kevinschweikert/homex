defmodule Homeassistant do
  @moduledoc """
  Documentation for `Homeassistant`.
  """
  @device_schema [
                   identifiers: [required: true, type: {:list, :string}],
                   name: [required: false, type: :string],
                   manufacturer: [required: false, type: :string],
                   model: [required: false, type: :string],
                   serial_number: [required: false, type: :string],
                   sw_version: [required: false, type: :string],
                   hw_version: [required: false, type: :string]
                 ]
                 |> NimbleOptions.new!()

  @origin_schema [
                   name: [required: true, type: :string],
                   sw_version: [required: false, type: :string],
                   support_url: [required: false, type: :string]
                 ]
                 |> NimbleOptions.new!()

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

  def device do
    Application.get_env(:homeassistant_ex, :device, [])
    |> NimbleOptions.validate!(@device_schema)
    |> Enum.into(%{})
  end

  def origin do
    Application.get_env(:homeassistant_ex, :origin, [])
    |> NimbleOptions.validate!(@origin_schema)
    |> Enum.into(%{})
  end

  def discovery_prefix do
    Application.get_env(:homeassistant_ex, :discovery_prefix, "homeassistant")
  end

  def config(components) do
    %{
      device: device(),
      origin: origin(),
      components: components,
      qos: 1
    }
  end
end
