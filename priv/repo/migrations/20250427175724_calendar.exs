defmodule Estore.Repo.Migrations.Calendar do
  use Ecto.Migration

  def change do
    create table("calendar_resources", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:content_size, :integer)
      add(:type, :string)
      add(:entries, {:array, :string})
      add(:root_id, references(:calendar_resources, on_delete: :delete_all, type: :uuid))
    end
  end
end
