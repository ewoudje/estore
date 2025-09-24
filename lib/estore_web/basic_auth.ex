defmodule EstoreWeb.BasicAuth do
  @behaviour Plug
  alias Plug.Conn

  @impl true
  def init(opts) do
    %{options: opts}
  end

  @impl true
  def call(conn, %{options: options}) do
    :telemetry.span([:estore, :auth], %{}, fn ->
      {case get_auth_header(conn) do
         {:ok, auth_header} ->
           case validate_credentials(auth_header, options) do
             {:ok, user} ->
               %{conn | params: Map.put(conn.params, :user, user)}

             {:error, _} ->
               Conn.halt(Conn.send_resp(conn, 401, "Unauthorized"))
           end

         {:error, _} ->
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

  defp validate_credentials(auth_header, _) do
    case String.split(auth_header, " ") do
      ["Basic", credentials] ->
        decoded_credentials = Base.decode64!(credentials)
        [username, password] = String.split(decoded_credentials, ":")

        Estore.UserAuth.auth(username, password)

      _ ->
        {:error, :invalid_auth_header}
    end
  end
end
