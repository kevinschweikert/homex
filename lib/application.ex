defmodule Homeassistant.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      %{
        id: :emqtt,
        start: {:emqtt, :start_link, emqtt_opts()}
      }
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Homeassistant.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp emqtt_opts do
    # TODO: move to config

    host = System.get_env("MQTT_HOST", "localhost") |> String.to_charlist()
    port = System.get_env("MQTT_PORT", "1883") |> String.to_integer()
    user = System.get_env("MQTT_USER", "admin") |> String.to_charlist()
    password = System.get_env("MQTT_PASS", "admin") |> String.to_charlist()

    [
      [
        name: Homeassistant.Client.name(),
        host: host,
        port: port,
        username: user,
        password: password
      ]
    ]
  end
end
