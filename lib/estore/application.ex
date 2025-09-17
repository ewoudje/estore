defmodule Estore.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :logger.add_handler(:sentry_handler, Sentry.LoggerHandler, %{})
    OpentelemetryBandit.setup()
    OpentelemetryPhoenix.setup(adapter: :bandit)
    OpentelemetryEcto.setup([:estore, :repo], db_statement: :enabled)

    children = [
      EstoreWeb.Telemetry,
      Estore.Repo,
      {DNSCluster, query: Application.get_env(:estore, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Estore.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Estore.Finch},
      Estore.POP3Server,
      # Start a worker by calling: Estore.Worker.start_link(arg)
      # {Estore.Worker, arg},
      # Start to serve requests, typically the last entry
      EstoreWeb.Endpoint
    ]

    children =
      if System.get_env("REQUEST_BODY_LOGGING") && System.get_env("REQUEST_BODY_LOGGING") != "0" do
        [EstoreWeb.RequestBodyLogging | children]
      else
        children
      end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Estore.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    EstoreWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
