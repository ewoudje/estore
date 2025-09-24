defmodule EstoreWeb.ErrorHTML do
  use EstoreWeb, :controller

  def render(_, %{status: status, stack: stack, conn: conn, reason: err}) do
    Sentry.capture_exception(err, stacktrace: stack)
    Plug.Conn.send_resp(conn, status, "")
  end
end
