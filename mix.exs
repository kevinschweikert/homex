defmodule Homex.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/kevinschweikert/homex"

  def project do
    [
      app: :homex,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package()
    ]
  end

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
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Entities: [
          Homex.Entity,
          Homex.Entity.Switch,
          Homex.Entity.Sensor,
          Homex.Entity.Light,
          Homex.Entity.Camera
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      # TODO: when https://github.com/emqx/emqtt/issues/289 is fixed:
      # {:emqtt, "1.14.4", system_env: [{"BUILD_WITHOUT_QUIC", "1"}]},
      {:emqtt, github: "emqx/emqtt", tag: "1.14.4", system_env: [{"BUILD_WITHOUT_QUIC", "1"}]},
      {:ex_doc, "~> 0.38", only: :dev},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"}
    ]
  end
end
