import Config

# Configures Elixir's Logger
config :logger, :default_handler, level: :error

config :logger, :default_formatter, format: "$time $message $metadata"

import_config "#{Mix.env()}.exs"
