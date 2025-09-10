defmodule EstoreWeb.OptionsController do
  use EstoreWeb, :controller

  def options(conn, input) do
    conn
    |> Plug.Conn.put_resp_header(
      "allow",
      "OPTIONS, PROPFIND, PROPPATCH, GET, HEAD, POST, DELETE, PUT, COPY, MOVE, MKCOL, REPORT"
    )
    |> Plug.Conn.send_resp(200, "")
  end
end
