# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :backalley,
  ecto_repos: [Backalley.Repo]

# Configures the endpoint
config :backalley, BackalleyWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "fcI85IeCzwCxQN2mW7quHTN7yQ/m4bqKm+0OXHj8cwjYjrZhZRr+moITMy9aRyGE",
  render_errors: [view: BackalleyWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: Backalley.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [
    signing_salt: "zfXnUXlCYu22UmoUZZ1mn6/ENeN1xFHU"
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
