defmodule Estore.DeadProperty do
  use Ecto.Schema

  require Ecto.Query

  import Ecto.Changeset

  schema "dead_properties" do
    field(:namespace, :string)
    field(:local_name, :string)
    field(:content, :string)
    belongs_to(:resource, Estore.Resource, type: Ecto.UUID)
    timestamps()
  end

  def set(resource, {{namespace, local_name}, _, _} = content) do
    Estore.Repo.insert(
      %Estore.DeadProperty{
        namespace: namespace,
        local_name: local_name,
        content: Estore.XML.encode(content, %{href_uuid: true}),
        resource: resource
      },
      on_conflict: :replace_all,
      conflict_target: [:resource_id, :namespace, :local_name]
    )
  end

  @doc false
  def changeset(directory, attrs) do
    directory
    |> cast(attrs, [:namespace, :local_name, :content])
    |> cast_assoc(:resource)
    |> validate_required([:namespace, :local_name, :content])
  end
end

defmodule Estore.DeadExtension do
  require Ecto.Query
  use Estore.Extension

  @impl true
  def fetch(_), do: {:ok, nil}

  @impl true
  def properties(resource, nil, {ns, name}) do
    case Estore.DeadProperty
         |> Ecto.Query.where(resource_id: ^resource.id, namespace: ^ns, local_name: ^name)
         |> Estore.Repo.one() do
      nil ->
        :not_found

      property ->
        {:value, elem(Estore.XML.decode(property.content), 2)}
    end
  end

  @impl true
  def prep_set(_, _, set), do: set

  @impl true
  # TODO
  def prep_remove(_, _, _), do: :not_allowed

  def apply_prep(resource, nil, {:set, property}) do
    Estore.DeadProperty.set(resource, property)
    :ok
  end

  @impl true
  def serves_property?(_, _), do: true
end
