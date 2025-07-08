# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :ex_streams,
  generators: [timestamp_type: :utc_datetime]

config :ex_streams, :streamer_url, "wss://stream.binance.com:9443/ws/btcusdt@trade"

# Configures the endpoint
config :ex_streams, ExStreamsWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ExStreamsWeb.ErrorHTML, json: ExStreamsWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: :pubsub,
  live_view: [signing_salt: "FT2G7RdM"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"

# Environment configuration added by mix assets.install
config :ex_streams, :env, config_env()
