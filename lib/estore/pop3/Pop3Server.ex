defmodule Estore.POP3Server do
  use Task, restart: :transient
  require Logger

  def start_link(opts) do
    Task.start_link(__MODULE__, :run, opts)
  end

  def run() do
    port = Application.get_env(:estore, :pop3_port, 110)

    {:ok, socket} =
      :gen_tcp.listen(
        port,
        [
          :binary,
          packet: :line,
          reuseaddr: true
        ]
      )

    Logger.log(:info, "Listening for POP3 at port #{port}")
    loop(socket)
  end

  defp loop(socket) do
    case :gen_tcp.accept(socket) do
      {:ok, client_socket} ->
        Estore.POP3Connection.start(client_socket)

      {:error, err} ->
        Logger.error("Failed to accept, error: #{inspect(err)}")
    end

    loop(socket)
  end
end
