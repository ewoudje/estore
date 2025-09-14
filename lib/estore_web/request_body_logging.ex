defmodule EstoreWeb.RequestBodyLogging do
  use GenServer

  def start_link(opts) do
    if System.get_env("REQUEST_BODY_LOGGING") do
      max = String.to_integer(System.get_env("REQUEST_BODY_LOGGING"))

      if max > 0 do
        GenServer.start_link(__MODULE__, {0, max}, name: __MODULE__)
      end
    end
  end

  def request_body(body) do
    GenServer.cast(__MODULE__, {:body, body})
  end

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def handle_cast({:body, body}, {idx, max}) do
    n_idx = idx + 1

    if n_idx >= max do
      n_idx = 0
    end

    File.write!("request#{idx}_body.xml", body)

    {:noreply, {n_idx, max}}
  end
end
