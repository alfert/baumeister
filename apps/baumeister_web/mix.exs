defmodule BaumeisterWeb.Mixfile do
  use Mix.Project

  def project do
    [app: :baumeister_web,
     version: "0.2.0-dev",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.2",
     elixirc_paths: elixirc_paths(Mix.env),
     compilers: [:phoenix, :gettext] ++ Mix.compilers,
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     aliases: aliases(),
     deps: deps()]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [mod: {BaumeisterWeb, []},
     extra_applications: [:logger],
     start_phases: [mnesia_up: [], operational: []]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [{:phoenix, "~> 1.3-rc"},
     {:phoenix_pubsub, "~> 1.0"},
     {:phoenix_ecto, "~> 3.0"},
     {:ecto_mnesia, "~> 0.9"},
     {:phoenix_html, "~> 2.6"},
     {:phoenix_live_reload, "~> 1.0", only: :dev},
     {:baumeister_coordinator, in_umbrella: true},
     {:gettext, "~> 0.11"},
     {:cowboy, "~> 1.0"}]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    ["ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
     "ecto.reset": ["ecto.drop", "ecto.setup"],
     "ecto.create": [&ensure_dirs/1, "ecto.create"],
     "test": ["ecto.create", "ecto.migrate", "test"]]
  end

  defp ensure_dirs(_) do
    mnesia_dir = "#{Application.get_env(:mnesia, :dir)}"
    [mnesia_dir]
     |> Enum.map(&Path.absname/1)
     |> Enum.each(fn dir ->
       Mix.shell.info "Ensure the existence of Mnesia Data: #{dir}"
       if File.exists?(dir) do
         Mix.shell.info("Mnesia Data Dir exists")
       else
         :ok = File.mkdir_p("#{dir}")
         Mix.shell.info("Mnesia Data Dir created")
       end
     end)
  end
end
