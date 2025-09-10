defmodule Estore.Repo.Migrations.Resources do
  use Ecto.Migration

  def change do
    create table("sources") do
      add(:type, :string)
      add(:data, :map)
    end

    create table("resources", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:fqn, :string)
      add(:collection, :boolean)

      add(
        :parent_id,
        references(:resources, on_delete: :delete_all, type: :uuid)
      )

      add(
        :owner_id,
        references(:resources, on_delete: :nilify_all, type: :uuid)
      )

      add(
        :source_id,
        references(:sources, on_delete: :nilify_all)
      )

      timestamps()
    end

    create(index("resources", [:fqn], unique: true))

    create table("files", primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:large_object, :oid)
      add(:content_size, :bigint)
      add(:content_type, :string)
    end

    execute("""
      CREATE OR REPLACE FUNCTION delete_file_lo()
      RETURNS TRIGGER
      AS
      $$
      BEGIN
          PERFORM lo_unlink(OLD.large_object);

          RETURN OLD;
      END;
      $$
      LANGUAGE plpgsql;
    """)

    execute("""
      CREATE TRIGGER after_delete_file_lo
        AFTER DELETE ON files
        FOR EACH ROW
        WHEN (OLD.large_object IS NOT NULL)
        EXECUTE FUNCTION delete_file_lo();
    """)
  end
end
