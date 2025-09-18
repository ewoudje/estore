defmodule Estore.POP3Connection do
  use GenServer

  def start(socket) do
    {:ok, pid} = GenServer.start(__MODULE__, socket)
    :gen_tcp.controlling_process(socket, pid)
    :inet.setopts(socket, active: true)
  end

  @impl true
  def init(socket) do
    ok(socket, "POP3 server ready")
    {:ok, {:auth, %{}}}
  end

  @impl true
  def handle_info({:tcp, socket, msg}, {state, mem}) do
    msg = String.trim(msg)

    case (if String.contains?(msg, " ") do
            [cmd, param] = String.split(msg, " ", parts: 2, trim: true)
            command(socket, String.upcase(cmd), param, state, mem)
          else
            command(socket, String.upcase(msg), nil, state, mem)
          end) do
      :quit -> {:stop, :normal, {state, mem}}
      {:ok, state, mem} -> {:noreply, {state, mem}}
      {:error, e} -> {:stop, e, {state, mem}}
    end
  end

  def handle_info({:tcp_closed, socket}, state) do
    {:stop, :normal, state}
  end

  defp command(socket, "CAPA", nil, state, mem) do
    ok(socket)
    list(socket, ["USER", "UIDL"])
    {:ok, state, mem}
  end

  defp command(socket, "QUIT", nil, :auth, _) do
    ok(socket, "POP3 quiting (auth state)")
    :quit
  end

  defp command(socket, "USER", username, :auth, mem) do
    ok(socket, "username selected")
    {:ok, :auth, Map.put(mem, :username, username)}
  end

  defp command(socket, "PASS", password, :auth, %{username: username}) do
    case Estore.UserAuth.auth(username, password) do
      {:ok, user} ->
        ok(socket, "password valid")

        mails = Estore.Mails.get_from_user(user)
        all_mails = Estore.Mails.all_mails(mails)
        IO.inspect(all_mails)
        {:ok, :trns, %{user: user, mails: all_mails}}

      {:error, _} ->
        err(socket, "login failed")
        {:ok, :auth, %{}}
    end
  end

  defp command(socket, "NOOP", nil, :trns, mem) do
    ok(socket)
    {:ok, :trns, mem}
  end

  defp command(socket, "STAT", nil, :trns, %{mails: mails} = mem) do
    ok(socket, "#{length(mails)} 99999999")
    {:ok, :trns, mem}
  end

  defp command(socket, "LIST", nil, :trns, %{mails: mails} = mem) do
    ok(socket, "listing messages")
    list(socket, mails |> Enum.with_index() |> Enum.map(fn {v, i} -> "#{i} 1024" end))
    {:ok, :trns, mem}
  end

  defp command(socket, "LIST", n, :trns, mem) do
    n = String.to_integer(n)
    size = 1024
    ok(socket, "#{n} #{size}")
    {:ok, :trns, mem}
  end

  defp command(socket, "UIDL", nil, :trns, %{mails: mails} = mem) do
    ok(socket, "listing messages")
    list(socket, mails |> Enum.with_index() |> Enum.map(fn {v, i} -> "#{i} #{v.id}" end))
    {:ok, :trns, mem}
  end

  defp command(socket, "UIDL", n, :trns, %{mails: mails} = mem) do
    n = String.to_integer(n)
    mail = Enum.at(mails, n)
    ok(socket, "#{n} #{mail.id}")
    {:ok, :trns, mem}
  end

  defp command(socket, "RETR", n, :trns, %{mails: mails} = mem) do
    n = String.to_integer(n)
    mail = Enum.at(mails, n)
    {:ok, content} = Estore.Source.read(mail)
    ok(socket, "listing message")
    list(socket, String.split(content, "\r\n"))
    {:ok, :trns, mem}
  end

  defp command(socket, "DELE", n, :trns, mem) do
    n = String.to_integer(n)
    ok(socket, "message marked for delete")
    {:ok, :trns, Map.put(mem, :marked2del, [n | Map.get(mem, :marked2del)])}
  end

  defp command(socket, "RSET", nil, :trns, mem) do
    ok(socket)
    {:ok, :trns, Map.delete(mem, :marked2del)}
  end

  defp command(socket, "QUIT", nil, :trns, mem) do
    ok(socket)
    {:ok, :update, mem}
  end

  defp command(socket, _, _, state, _) do
    err(socket, "Invalid command in the current state (#{state}), reseting memory")
    {:ok, state, %{}}
  end

  defp list(socket, lst) do
    for e <- lst do
      :gen_tcp.send(socket, e <> "\r\n")
    end

    :gen_tcp.send(socket, ".\r\n")
  end

  defp ok(socket, msg \\ nil) do
    if msg do
      :gen_tcp.send(socket, "+OK " <> msg <> "\r\n")
    else
      :gen_tcp.send(socket, "+OK\r\n")
    end
  end

  defp err(socket, msg \\ nil) do
    if msg do
      :gen_tcp.send(socket, "-ERR " <> msg <> "\r\n")
    else
      :gen_tcp.send(socket, "-ERR\r\n")
    end
  end
end
