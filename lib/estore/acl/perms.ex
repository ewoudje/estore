defmodule Estore.PermsExtension do
  use Estore.Extension
  use Ecto.Schema
  import Ecto.Changeset

  # schema "perms" do
  #  belongs_to(:principal, Estore.Resource, type: Ecto.UUID)
  #  belongs_to(:resource, Estore.Resource, type: Ecto.UUID)
  #  field(:permissions, :string)
  #
  #   timestamps()
  # end

  # @impl true
  # def fetch(resource) do
  # require Ecto.Query

  # case Ecto.Query.where(resource: ^resource) |> Estore.Repo.all() do
  #  [] -> :not_found
  #  nil -> :not_found
  #  perms -> {:ok, perms}
  # end
  #  end
  #

  @impl true
  def fetch(_), do: {:ok, nil}

  def serves_property?("DAV:", "current-user-principal"), do: true
  def serves_property?("DAV:", "current-user-privilege-set"), do: true
  def serves_property?("DAV:", "acl"), do: true

  def properties(resource, nil, {"DAV:", "current-user-principal"}) do
    {:value, {{"DAV:", "href"}, [], ["/users/admin/"]}}
  end

  def properties(resource, nil, {"DAV:", "current-user-privilege-set"}) do
    {:value,
     Enum.map(
       [
         {"DAV:", "read"},
         {"DAV:", "all"},
         {"DAV:", "write"},
         {"DAV:", "write-properties"},
         {"DAV:", "write-content"}
       ],
       &{{"DAV:", "privilege"}, [], [{&1, [], []}]}
     )}
  end

  def properties(resource, nil, {"DAV:", "acl"}) do
    {:value,
     [
       {{"DAV:", "ace"}, [],
        [
          {{"DAV:", "principal"}, [], [{{"DAV:", "href"}, [], ["/users/admin"]}]},
          {{"DAV:", "grant"}, [], [{{"DAV:", "privilege"}, [], [{{"DAV:", "all"}, [], []}]}]}
        ]}
     ]}
  end
end
