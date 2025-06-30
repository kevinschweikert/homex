defmodule Homex.MixProject do
  use Mix.Project

  def project do
    [
      app: :homex,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:emqtt, github: "emqx/emqtt", tag: "1.14.4", system_env: [{"BUILD_WITHOUT_QUIC", "1"}]},
      {:ex_doc, "~> 0.38", only: :dev},
      {:jason, "~> 1.4"},
      {:nimble_options, "~> 1.1"}
    ]
  end
end
