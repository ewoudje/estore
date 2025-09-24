defmodule EstoreWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :estore

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  @session_options [
    store: :cookie,
    key: "_estore_key",
    signing_salt: "2T9ZN31G",
    same_site: "Lax"
  ]

  # Idk plug Sentry.PlugCapture

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phx.digest
  # when deploying your static files in production.
  plug(Plug.Static,
    at: "/",
    from: :estore,
    gzip: false,
    only: EstoreWeb.static_paths()
  )

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug(Phoenix.CodeReloader)
    plug(Phoenix.Ecto.CheckRepoStatus, otp_app: :estore)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)
  plug(EstoreWeb.Router)
  plug Sentry.PlugContext

  plug :not_found

  def not_found(conn, _) do
    send_resp(conn, 404, "not found")
  end
end
