defmodule Estore.Resource do
  use Ecto.Schema
  use Arbor.Tree, foreign_key_type: Ecto.UUID

  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "resources" do
    field(:fqn, :string)
    field(:collection, :boolean)
    belongs_to(:source, Estore.Source)
    belongs_to(:parent, Estore.Resource, type: Ecto.UUID)
    belongs_to(:owner, Estore.Resource, type: Ecto.UUID)
    timestamps()
  end

  def create_root() do
    Estore.Repo.insert!(%Estore.Resource{
      fqn: "/",
      parent: nil,
      collection: true,
      owner: nil,
      source: nil
    })
  end

  def create(parent, name, collection, opts \\ []) do
    Estore.Repo.insert!(%Estore.Resource{
      fqn:
        if String.ends_with?(parent.fqn, "/") do
          parent.fqn
        else
          parent.fqn <> "/"
        end <> name,
      parent: parent,
      collection: collection,
      source: elem(List.keyfind(opts, :source, 0, {nil, nil}), 1),
      owner: elem(List.keyfind(opts, :owner, 0, {nil, nil}), 1),
      owner_id: elem(List.keyfind(opts, :owner_id, 0, {nil, nil}), 1)
    })
    |> Estore.Source.init()
  end

  def get_fqn(path) do
    "/" <>
      (path
       |> String.split("/")
       |> Enum.filter(fn x -> x != "" end)
       |> Enum.join("/"))
  end

  def get_by_path(path) do
    Estore.Repo.get_by(Estore.Resource, fqn: get_fqn(path))
  end

  def get_family(resource, depth \\ "1") do
    [
      resource
      | case depth do
          :zero -> []
          :one -> resource |> Estore.Resource.children() |> Estore.Repo.all()
          :infinity -> resource |> Estore.Resource.descendants() |> Estore.Repo.all()
        end
    ]
  end

  def get_href(%Estore.Resource{fqn: fqn, collection: collection}) do
    if not collection or fqn == "/" do
      fqn
    else
      fqn <> "/"
    end
  end

  def get_etag(%Estore.Resource{id: id, updated_at: updated_at}) do
    "e-#{:erlang.phash2({id, updated_at})}-1"
  end

  def get_parent(fqn) do
    if fqn == "/" do
      nil
    else
      path = String.split(String.slice(fqn, 1..-1//1), "/")
      parent_path = "/" <> (Enum.slice(path, 0..-2//1) |> Enum.join("/"))
      Estore.Repo.get_by(Estore.Resource, fqn: parent_path)
    end
  end

  def add_source_extensions(resource, extensions) do
    Estore.Source.add_extensions(Estore.Repo.preload(resource, :source).source, extensions)
  end

  @doc false
  def changeset(directory, attrs) do
    directory
    |> cast(attrs, [:fqn, :id, :parent_id])
    |> cast_assoc(:parent)
    |> cast_assoc(:source)
    |> validate_required([:fqn])
  end
end
