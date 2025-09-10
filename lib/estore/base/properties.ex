defmodule Estore.StdProperties do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, []}
  schema "std_properties" do
    field(:display_name, :string)
    timestamps()
  end

  def set(resource, display_name) do
    Estore.Repo.insert(
      %Estore.StdProperties{
        id: resource.id,
        display_name: display_name
      },
      on_conflict: :replace_all,
      conflict_target: [:id]
    )
  end

  def of(%Estore.Resource{id: id, fqn: fqn}) do
    case Estore.Repo.get(Estore.StdProperties, id) do
      nil ->
        %Estore.StdProperties{
          id: id,
          display_name: fqn
        }

      stdprops ->
        stdprops
    end
  end

  @doc false
  def changeset(directory, attrs) do
    directory
    |> cast(attrs, [:display_name])
    |> validate_required([:display_name])
  end
end
