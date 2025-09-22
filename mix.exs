defmodule Estore.MixProject do
  use Mix.Project

  def project do
    [
      app: :estore,
      version: version(),
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Estore.Application, []},
      extra_applications: [
        :logger,
        :runtime_tools,
        :sync
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:pbkdf2_elixir, "~> 2.0"},
      {:phoenix, "~> 1.7.19"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13.2"},
      {:postgrex, ">= 0.0.0"},
      {:swoosh, "~> 1.5"},
      {:finch, "~> 0.13"},
      {:dns_cluster, "~> 0.1.1"},
      {:bandit, "~> 1.5"},
      {:saxy, "~> 1.6"},
      {:cachex, "~> 4.1"},
      {:arbor, "~> 1.1.0"},
      {:hackney, "~> 1.25"},
      # {:mail, "~> 0.4"},

      {:sentry, "~> 11.0"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      # OpenTelemetry core packages
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_exporter, "~> 1.0"},
      {:opentelemetry_semantic_conventions, "~> 1.27"},

      # Instrumentation libraries (choose what you need)
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_bandit, "~> 0.1"},
      {:opentelemetry_ecto, "~> 1.2"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "assets.setup", "assets.build"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind estore", "esbuild estore"],
      "assets.deploy": [
        "tailwind estore --minify",
        "esbuild estore --minify",
        "phx.digest"
      ]
    ]
  end

  def version() do
    text = File.read!("README.md")
    [_, version | _] = Regex.run(~r/> Current version: (.*)(\r)?\n/, text)
    version
  end

  def set_version(version) do
    text = File.read!("README.md")

    text =
      Regex.replace(
        ~r/> Current version: (.*)\n/,
        text,
        "> Current version: " <> version <> "\n"
      )

    File.write!("README.md", text)
  end
end
