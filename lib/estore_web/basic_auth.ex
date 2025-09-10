defmodule EstoreWeb.BasicAuth do
  @behaviour Plug
  alias Plug.Conn

  @impl true
  def init(opts) do
    opts
  end

  @impl true
  def call(conn, options) do
    :telemetry.span([:estore, :auth], %{}, fn ->
      {case get_auth_header(conn) do
         {:ok, auth_header} ->
           case validate_credentials(auth_header, options) do
             {:ok, user} ->
               %{conn | params: Map.put(conn.params, :user, user)}

             {:error, reason} ->
               Conn.halt(Conn.send_resp(conn, 401, "Unauthorized"))
           end

         {:error, reason} ->
           conn
           |> Conn.put_resp_header("WWW-Authenticate", "Basic realm=\"Estore\"")
           |> Conn.send_resp(401, "Unauthorized")
           |> Conn.halt()
       end, %{}}
    end)
  end

  defp get_auth_header(conn) do
    case Plug.Conn.get_req_header(conn, "authorization") do
      [] -> {:error, :missing_auth_header}
      [auth_header] -> {:ok, auth_header}
    end
  end

  defp validate_credentials(auth_header, options) do
    case String.split(auth_header, " ") do
      ["Basic", credentials] ->
        decoded_credentials = Base.decode64!(credentials)
        [username, password] = String.split(decoded_credentials, ":")
        user = Estore.Repo.get_by(Estore.User, username: username)

        if valid_credentials?(username, password, user) do
          {:ok, user}
        else
          {:error, :invalid_credentials}
        end

      _ ->
        {:error, :invalid_auth_header}
    end
  end

  defp valid_credentials?(username, password, user) do
    case user do
      nil ->
        false

      user ->
        Pbkdf2.verify_pass(password, user.password_hash)
    end
  end
end
