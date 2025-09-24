defmodule EstoreWeb.ErrorHTML do
  use EstoreWeb, :controller

  def render(template, %{status: s, conn: conn, reason: err, stack: s}) do
    Sentry.capture_exception(err, stacktrace: s)
    Plug.Conn.send_resp(conn, s, "")
  end
end
