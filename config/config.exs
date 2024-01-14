import Config

# Configures Elixir's Logger
config :logger, :default_handler, level: :error

config :logger, :default_formatter, format: "$time $message $metadata"

config :superls,
  secret_key_base: "bqpBY/700YM3ns8e6fSAUtA4fx3/I+w/Xeoma6kn9xCS9XZc6KzWx54yl7XLHMIf"

import_config "#{Mix.env()}.exs"
