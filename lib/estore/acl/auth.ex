defmodule Estore.UserAuth do
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(args) do
    Supervisor.init(
      [
        {Cachex, :auth_cache}
      ],
      strategy: :one_for_one
    )
  end

  def auth(username, password) do
    k = :erlang.phash2(username <> password)

    case Cachex.get(:auth_cache, k) do
      {:ok, nil} ->
        Sentry.Context.add_breadcrumb(%{
          message: "cache missed for auth",
          category: "chache_miss",
          type: "auth",
          level: :debug
        })

        v = calculate_auth(username, password)

        Cachex.put(:auth_cache, k, v, expire: :timer.seconds(5))
        v

      {:ok, v} ->
        Sentry.Context.add_breadcrumb(%{
          message: "cache hit for auth",
          category: "cache_hit",
          type: "auth",
          level: :debug
        })

        Cachex.expire(:auth_cache, k, :timer.seconds(5))
        v

      {:error, _} = e ->
        e
    end
  end

  defp calculate_auth(username, password) do
    case Estore.Repo.get_by(Estore.User, username: username) do
      nil ->
        {:error, :invalid_user}

      user ->
        if Pbkdf2.verify_pass(password, user.password_hash) do
          {:ok, user}
        else
          {:error, :invalid_password}
        end
    end
  end
end
