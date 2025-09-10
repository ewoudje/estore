defmodule Estore.User do
  use Estore.Source
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field(:password_hash, :string)
    field(:username, :string)
    belongs_to(:principal, Estore.Resource, type: Ecto.UUID)

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:username, :password_hash, :principal_id])
    |> cast_assoc(:principal)
    |> validate_required([:username, :password_hash])
  end

  def create_user(attrs) do
    %Estore.User{}
    |> changeset(attrs)
    |> Estore.Repo.insert()
  end

  @impl true
  def fetch(%Estore.Resource{id: id}) do
    case Estore.Repo.get_by(Estore.User, principal_id: id) do
      nil -> :not_found
      user -> {:ok, user}
    end
  end

  @impl true
  def new(%{}, %Estore.Resource{id: id}) do
    :ok
  end

  def serves_property?("DAV:", "alternate-URI-set"), do: true
  def serves_property?("DAV:", "principal-URL"), do: true
  def serves_property?("DAV:", "group-membership"), do: true
  def serves_property?("DAV:", "resourcetype"), do: true
  def serves_property?("urn:ietf:params:xml:ns:caldav", "calendar-home-set"), do: true

  def properties(resource, f, {"DAV:", "alternate-URI-set"}), do: {:empty}
  def properties(resource, f, {"DAV:", "principal-URL"}), do: {:value, {:href, resource}}
  def properties(resource, f, {"DAV:", "group-membership"}), do: {:empty}

  def properties(resource, f, {"urn:ietf:params:xml:ns:caldav", "calendar-home-set"}),
    do: {:value, {{"DAV:", "href"}, [], ["/users/admin/"]}}

  def properties(resource, f, {"DAV:", "resourcetype"}),
    do: {:append, {{"DAV:", "principal"}, [], []}}
end
