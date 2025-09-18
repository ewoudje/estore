defmodule Estore.Mails do
  use Estore.Source
  use Ecto.Schema
  import Ecto.Changeset
  @ns "urn:ietf:params:xml:ns:caldav"

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "mailss" do
    timestamps()
  end

  def changeset(user, attrs) do
    user
    # |> cast(attrs, [])
    # |> cast_assoc(:resource)
    # |> validate_required([:resource_id])
  end

  @impl true
  def fetch(%Estore.Resource{id: id}) do
    case Estore.Repo.get_by(Estore.Mails, id: id) do
      nil -> :not_found
      mails -> {:ok, mails}
    end
  end

  @impl true
  def new(%{}, %Estore.Resource{id: id}) do
    Estore.Repo.insert!(%Estore.Mails{
      id: id
    })

    :ok
  end

  def get_from_user(%Estore.User{principal_id: pcp_id}) do
    import Ecto.Query

    mail_pair = from m in Estore.Mails, join: r in Estore.Resource, on: m.id == r.id
    Estore.Repo.one(from [m, r] in mail_pair, where: r.owner_id == ^pcp_id, select: m)
  end

  def all_mails(%Estore.Mails{id: id}) do
    Estore.Repo.get_by(Estore.Resource, id: id)
    |> Estore.Resource.children()
    |> Estore.Repo.all()
  end

  def serves_property?("DAV:", "resourcetype"), do: true

  def properties(resource, f, {"DAV:", "resourcetype"}),
    do: {:append, {{@ns, "mails"}, [], []}}
end
