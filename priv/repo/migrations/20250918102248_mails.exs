defmodule Estore.Repo.Migrations.Mails do
  use Ecto.Migration

  def change do
    create table("mailss", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      timestamps()
    end
  end
end
