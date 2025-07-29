defmodule ElixirGrpc.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_rpc,
      version: "1.0.0",
      elixir: "~> 1.18",
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
      {:jason, "~> 1.2"},
      {:grpc, "~> 0.5.0"},
      {:protobuf, "~> 0.11.0"},
      {:poolboy, "~> 1.5"}
    ]
  end
end
