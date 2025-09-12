defmodule EstoreWeb.BasicAuth do
  @behaviour Plug
  alias Plug.Conn

  @impl true
  def init(opts) do
    Cachex.start_link(:auth_cache)
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

  defp validate_credentials(auth_header, option) do
    case String.split(auth_header, " ") do
      ["Basic", credentials] ->
        decoded_credentials = Base.decode64!(credentials)
        [username, password] = String.split(decoded_credentials, ":")
        user = Estore.Repo.get_by(Estore.User, username: username)

        case get_cached_auth(credentials) do
          :invalid ->
            {:error, :invalid_credentials}

          :valid ->
            {:ok, user}

          :not_cached ->
            if valid_credentials?(password, user) do
              cache_auth(credentials, :valid)
              {:ok, user}
            else
              cache_auth(credentials, :invalid)
              {:error, :invalid_credentials}
            end
        end

      _ ->
        {:error, :invalid_auth_header}
    end
  end

  defp valid_credentials?(password, user) do
    case user do
      nil ->
        false

      user ->
        Pbkdf2.verify_pass(password, user.password_hash)
    end
  end

  defp get_cached_auth(credentials) do
    k = :erlang.phash2(credentials)

    case Cachex.get(:auth_cache, k) do
      {:ok, nil} ->
        Sentry.Context.add_breadcrumb(%{
          message: "cache missed for auth",
          category: "chache_miss",
          type: "auth",
          level: :debug
        })

        :not_cached

      {:ok, v} ->
        Sentry.Context.add_breadcrumb(%{
          message: "cache hit for auth",
          category: "cache_hit",
          type: "auth",
          level: :debug
        })

        Cachex.expire(:auth_cache, k, :timer.seconds(5))
        v
    end
  end

  defp cache_auth(credentials, v) do
    Cachex.put(:auth_cache, :erlang.phash2(credentials), v, expire: :timer.seconds(5))
  end
end
