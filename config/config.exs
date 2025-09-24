# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :estore,
  ecto_repos: [Estore.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures the endpoint
config :estore, EstoreWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  pubsub_server: Estore.PubSub,
  render_errors: [
    formats: [html: EstoreWeb.ErrorHTML],
    layout: false
  ]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :estore, Estore.Mailer, adapter: Swoosh.Adapters.Local

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :opentelemetry, span_processor: {Sentry.OpenTelemetry.SpanProcessor, []}
config :opentelemetry, sampler: {Sentry.OpenTelemetry.Sampler, []}

config :sentry,
  environment_name: Mix.env(),
  context_lines: 5,
  release: Estore.MixProject.version(),
  traces_sample_rate: 1.0,
  enable_source_code_context: true,
  root_source_code_paths: [File.cwd!()]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
