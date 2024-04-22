defmodule PingPongMeasurerRclex.MixProject do
  use Mix.Project

  def project do
    [
      app: :ping_pong_measurer_rclex,
      version: "0.1.0",
      elixir: "~> 1.13",
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
      {:rclex,
       git: "https://github.com/rclex/rclex.git", branch: "pojiro/apply-dynamic-timeout_us"},
      {:nimble_csv, "~> 1.1"},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:flow, "~> 1.0"},
      {:os_info_measurer, git: "https://github.com/b5g-ex/os_info_measurer.git"}
    ]
  end
end
