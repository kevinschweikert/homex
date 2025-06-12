defmodule Homeassistant do
  @moduledoc """
  Documentation for `Homeassistant`.
  """

  use Supervisor

  @defaults [
    name: __MODULE__.EMQTT,
    host: "localhost",
    port: 1883,
    username: "admin",
    password: "admin"
  ]

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children = [
      {PropertyTable, name: Homeassistant.EntityTable},
      %{
        id: :emqtt,
        start: {:emqtt, :start_link, [Keyword.merge(opts, @defaults)]}
      }
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def unique_id(name) do
    "#{entity_id(name)}_#{:erlang.phash2(name)}"
  end

  def entity_id(name) when is_binary(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_]/, "_")
  end
end
