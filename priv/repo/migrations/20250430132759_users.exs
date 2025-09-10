defmodule Estore.Repo.Migrations.Users do
  use Ecto.Migration

  def change do
    create table("users") do
      add(:password_hash, :string)
      add(:username, :string)
      add(:principal_id, references(:resources, on_delete: :delete_all, type: :uuid))

      timestamps()
    end
  end
end
