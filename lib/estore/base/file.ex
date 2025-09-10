defmodule Estore.File do
  use Estore.Source
  use Ecto.Schema

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "files" do
    field(:content_size, :integer)
    field(:content_type, :string)
    field(:large_object, :id)
  end

  def serves_property?("DAV:", "getcontentlength"), do: true
  def serves_property?("DAV:", "getcontenttype"), do: true

  def properties(_, f, {"DAV:", "getcontentlength"}), do: {:value, f.content_size}
  def properties(_, f, {"DAV:", "getcontenttype"}), do: {:value, f.content_type}

  @impl true
  def new(%{}, %Estore.Resource{id: id}) do
    Estore.Repo.query!(
      """
      INSERT INTO files (id, content_type, content_size, large_object) VALUES ($1, 'text/plain', 0, lo_creat(-1))
      """,
      [Ecto.UUID.dump!(id)]
    )

    :ok
  end

  @impl true
  def fetch(%Estore.Resource{id: id}) do
    case Estore.Repo.get(Estore.File, id) do
      nil ->
        :not_found

      file ->
        {:ok, file}
    end
  end

  @impl true
  def write(%{}, %Estore.Resource{id: id}, binary, state) do
    state = state || 0

    Estore.Repo.query!(
      "SELECT lo_put(large_object, $2, $3) FROM files WHERE (id = $1);",
      [Ecto.UUID.dump!(id), state, binary]
    )

    {:ok, state + byte_size(binary)}
  end

  @impl true
  def finish_write(%{}, %Estore.Resource{id: id}, state) do
    Estore.Repo.query!(
      "UPDATE files SET content_size = $1 WHERE (id = $2)",
      [state, Ecto.UUID.dump!(id)]
    )

    :ok
  end

  @impl true
  def read(%{}, %Estore.Resource{id: id}) do
    %{rows: [[content]]} =
      Estore.Repo.query!(
        "SELECT lo_get(large_object) FROM files WHERE (id = $1)",
        [Ecto.UUID.dump!(id)]
      )

    {:ok, content}
  end
end
