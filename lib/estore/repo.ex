defmodule Estore.Repo do
  use Ecto.Repo,
    otp_app: :estore,
    adapter: Ecto.Adapters.Postgres
end
