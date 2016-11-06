defmodule Baumeister.Mixfile do
  use Mix.Project

  def project do
    [app: :baumeister,
     version: "0.1.0",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :yaml_elixir, :elixometer],
     mod: {Baumeister, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:myapp, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:propcheck, "~> 0.0.1", only: :test},
      { :yaml_elixir, "~> 1.2.1" },
      {:gen_stage, "~> 0.8.0"},
      {:elixometer, "~> 1.2"},
      #lager 3.2.1 is needed for erl19 because of
      # https://github.com/basho/lager/pull/321
      {:lager, ">= 3.2.1", override: true},
      {:credo, "~> 0.5.0", only: :dev},
      {:dialyze, "~> 0.2.1", only: :dev}
    ]
  end
end
