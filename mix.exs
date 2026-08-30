defmodule Homex.MixProject do
  use Mix.Project

  @version "0.2.0-dev"
  @source_url "https://github.com/kevinschweikert/homex"

  def project do
    [
      app: :homex,
      version: @version,
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: [
        docs: :docs,
        "hex.publish": :docs
      ]
    ]
  end

  def package do
    [
      description: "A bridge between Elixir and Homeassistant ",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => "https://hexdocs.pm/homex/changelog.html"
      }
    ]
  end

  def docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "CHANGELOG.md", {"livebooks/intro.livemd", [title: "Intro Livebook"]}],
      assets: %{"assets" => "assets"},
      groups_for_modules: [
        Core: [
          Homex,
          Homex.Config,
          Homex.Device,
          Homex.Descriptor
        ],
        Entities: [
          Homex.Entity,
          Homex.Entity.Switch,
          Homex.Entity.Sensor,
          Homex.Entity.Light,
          Homex.Entity.Camera,
          Homex.Entity.Button,
          Homex.Entity.DeviceTrigger,
          Homex.Entity.Text,
          Homex.Entity.Number,
          Homex.Entity.Select
        ],
        Adapters: [
          Homex.Adapter.MQTT,
          Homex.Adapter.ESPHome,
          Homex.Adapter.ESPHome.Mdns.SystemResponder
        ],
        Livebook: [
          Homex.Livebook
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nimble_options, "~> 1.1"},
      {:emqtt, "~> 1.14.7", optional: true},
      {:jason, "~> 1.4", optional: true},
      {:kino, "~> 0.19", optional: true},
      {:espex, "~> 0.9.0", optional: true},
      {:muontrap, "~> 2.0", optional: true},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :docs}
    ]
  end
end
