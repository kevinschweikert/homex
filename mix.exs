defmodule Homeassistant.MixProject do
  use Mix.Project

  def project do
    [
      app: :homeassistant_ex,
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
      {:ex_doc, "~> 0.38", only: :dev},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:jason, "~> 1.4"},
      {:emqtt, github: "emqx/emqtt", tag: "1.14.4", system_env: [{"BUILD_WITHOUT_QUIC", "1"}]}
    ]
  end
end
