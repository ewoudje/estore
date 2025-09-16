defmodule EstoreWeb.RequestBodyLogging do
  use GenServer

  def start_link(opts) do
    max = String.to_integer(System.get_env("REQUEST_BODY_LOGGING"))

    if max > 0 do
      GenServer.start_link(__MODULE__, {0, max}, name: __MODULE__)
    end
  end

  def request_body(body, conn) do
    GenServer.cast(__MODULE__, {:body, body, Plug.Conn.request_url(conn)})
  end

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_cast({:body, body, url}, {idx, max}) do
    n_idx = idx + 1

    n_idx =
      if n_idx >= max do
        n_idx = 0
      else
        n_idx
      end

    File.write!("request#{idx}_body.xml", "<!-- url=\"" <> url <> "\"--!>" <> urlbody)

    {:noreply, {n_idx, max}}
  end
end
