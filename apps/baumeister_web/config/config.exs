# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :baumeister_web,
  ecto_repos: [BaumeisterWeb.Web.Repo]

# Configures the endpoint
config :baumeister_web, BaumeisterWeb.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "GUQyG6xy9iFCXA+MhEGSl6YiNebH8HFX/Yn+yzkM19Z8huITFq05oaxYZ9O4Mhjd",
  render_errors: [view: BaumeisterWeb.Web.ErrorView, accepts: ~w(html json)],
  pubsub: [name: BaumeisterWeb.Web.PubSub,
           adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Configure the Mnesia Database
config :ecto_mnesia,
  host: {:system, :atom, "MNESIA_HOST", Kernel.node()},
  storage_type: {:system, :atom, "MNESIA_STORAGE_TYPE", :disc_copies}

config :mnesia,
  dir: 'priv/data/mnesia' # Make sure this directory exists

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env}.exs"
