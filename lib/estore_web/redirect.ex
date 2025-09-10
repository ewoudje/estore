defmodule Plug.Redirect do
  alias Plug.Conn
  @behaviour Plug

  def init(opts) do
    opts
  end

  def call(conn, opts) do
    to = Keyword.get(opts, :to)

    conn
    |> Conn.put_resp_header("location", to)
    |> Conn.send_resp(301, "Redirecting to #{to}")
    |> Conn.halt()
  end
end
