defmodule Baumeister.Mixfile do
  use Mix.Project

  def project do
    [app: :baumeister_core,
     version: "0.2.0-dev",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.5",
     elixirc_paths: elixirc_paths(Mix.env),
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     docs: [ #main: "README.md",
      extras: ["README.md"],
      extra_section: "Baumeister Guides"
     ],
     test_coverage: [tool: Coverex.Task],
     deps: deps()]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [ # Specify extra applications you'll use from Erlang/Elixir
      extra_applications: [:sasl, :logger,
        # and elixometers undeclared apps
        :edown, :folsom, :parse_trans],
     mod: {Baumeister.App, []}]
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
      {:yaml_elixir, "~> 1.3.0"},
      {:confex, "~> 3.2"},
      {:gen_stage, "~> 0.12"},
      {:git_cli, "~> 0.2.2"},
      {:elixometer, "~> 1.2"},
      #lager 3.2.1 is needed for erl19 because of
      # https://github.com/basho/lager/pull/321
      {:lager, ">= 3.2.1", override: true},
      {:credo, "~> 0.8", only: :dev},
      {:dialyxir, "~> 0.5", only: [:dev, :test]},
      {:ex_doc, "~> 0.14.0", only: :dev},
      {:coverex, "~> 1.4.0", only: :test}
    ]
  end
end
