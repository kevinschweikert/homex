defmodule Homeassistant do
  @device_schema [
    identifiers: [required: true, type: {:list, :string}],
    name: [required: true, type: :string],
    manufacturer: [required: false, type: :string],
    model: [required: false, type: :string],
    serial_number: [required: false, type: :string],
    sw_version: [required: false, type: :string],
    hw_version: [required: false, type: :string]
  ]

  @origin_schema [
    name: [required: false, type: :string, default: "homex"],
    sw_version: [required: false, type: :string],
    support_url: [required: false, type: :string]
  ]

  @config_schema [
                   device: [
                     required: true,
                     type: {:or, [keyword_list: @device_schema]},
                     doc: "\n\n" <> NimbleOptions.docs(@origin_schema, nest_level: 1)
                   ],
                   origin: [
                     required: true,
                     type: {:or, [keyword_list: @origin_schema]},
                     doc: "\n\n" <> NimbleOptions.docs(@origin_schema, nest_level: 1)
                   ],
                   discovery_prefix: [required: false, type: :string, default: "homeassistant"],
                   qos: [required: false, type: :integer, default: 1]
                 ]
                 |> NimbleOptions.new!()

  @moduledoc """
  Documentation for `Homeassistant`.

  Configuration options:

  #{NimbleOptions.docs(@config_schema)}

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

  def discovery_prefix do
    Application.get_all_env(:homeassistant_ex)
    |> NimbleOptions.validate!(@config_schema)
    |> Keyword.get(:discovery_prefix)
  end

  def config(components) do
    config =
      Application.get_all_env(:homeassistant_ex)
      |> NimbleOptions.validate!(@config_schema)

    %{
      device: Enum.into(config[:device], %{}),
      origin: Enum.into(config[:origin], %{}),
      components: components,
      qos: config[:qos]
    }
  end
end
