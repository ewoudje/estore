defmodule Estore.Repo.Migrations.Properties do
  use Ecto.Migration

  def change do
    create table("std_properties", primary_key: false) do
      add(
        :id,
        references(:resources, on_delete: :delete_all, type: :uuid),
        primary_key: true
      )

      add(:display_name, :string)

      timestamps()
    end

    create table("dead_properties") do
      add(:namespace, :string)
      add(:local_name, :string)
      add(:content, :string)
      add(:resource_id, references(:resources, on_delete: :delete_all, type: :uuid))

      timestamps()
    end

    create(index("dead_properties", [:namespace, :local_name, :resource_id], unique: true))
  end
end
