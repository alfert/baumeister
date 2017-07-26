use Mix.Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :baumeister_web, BaumeisterWeb.Web.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :baumeister_web, BaumeisterWeb.Repo,
  adapter: EctoMnesia.Adapter
config :ecto_mnesia,
    host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
    storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :ram_copies}

config :mnesia,
  dir: Mix.Project.deps_path()
    |> Path.join("..")
    |> Path.join("priv/data/mnesia")
    |> Path.expand()
    |> String.to_charlist()
  # adapter: Ecto.Adapters.Postgres,
  # username: "postgres",
  # password: "postgres",
  # database: "baumeister_web_test",
  # hostname: "localhost",
  # pool: Ecto.Adapters.SQL.Sandbox
