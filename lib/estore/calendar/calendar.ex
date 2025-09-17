defmodule Estore.Calendar do
  use Estore.Source
  use Ecto.Schema
  import Ecto.Changeset

  @ns "urn:ietf:params:xml:ns:caldav"

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "calendar_resources" do
    field(:content_size, :integer)
    field(:type, Ecto.Enum, values: [:unknown, :root, :event])
    field(:entries, {:array, :string})
    belongs_to(:root, Estore.Calendar, type: Ecto.UUID)
  end

  @doc false
  def changeset(calendar, attrs) do
    calendar
    |> cast(attrs, [:content_size, :type, :entries, :root_id])
    |> cast_assoc(:root)
    |> validate_required([:content_size, :type, :entries])
  end

  @impl true
  def fetch(%Estore.Resource{id: id}) do
    {:ok, Estore.Repo.get!(Estore.Calendar, id)}
  end

  @impl true
  def serves_property?(@ns, name) do
    name in [
      "supported-calendar-component-set",
      "calendar-data"
    ]
  end

  @impl true
  def serves_property?("DAV:", "resourcetype"), do: true
  def serves_property?("DAV:", "getcontenttype"), do: true

  @impl true
  def serves_property?(namespace, name), do: false

  @impl true
  def properties(resource, f, requested) do
    case requested do
      # {@ns, "supported-calendar-component-set"} ->
      #  {:value, Enum.map(["EVENT", "CALENDAR"], &{{@ns, "comp"}, [{"name", &1}], []})}

      {@ns, "calendar-data"} ->
        {:value, _read(f)}

      {"DAV:", "resourcetype"} ->
        if (resource.collection and f.type == :root) or f.type != :root do
          {:append, {{@ns, "calendar"}, [], []}}
        else
          :not_found
        end

      {"DAV:", "getcontenttype"} ->
        {:value, "text/calendar"}

      _ ->
        :not_found
    end
  end

  @impl true
  def remove_properties(resource, stdprops, remove), do: :not_allowed

  @impl true
  def new(%{}, %Estore.Resource{id: id}) do
    Estore.Repo.insert!(%Estore.Calendar{
      id: id,
      content_size: 0,
      type: :unknown,
      root: nil,
      entries: []
    })

    :ok
  end

  def configure_calendar_root(%Estore.Resource{id: id}) do
    Estore.Repo.update!(Ecto.Changeset.change(%Estore.Calendar{id: id}, type: :root, entries: []))
  end

  @impl true
  def write(%{}, %Estore.Resource{id: id}, binary, state) do
    state = state || []
    lines = Estore.ICS.into_lines(binary)
    {:ok, state ++ lines}
  end

  @impl true
  def finish_write(%{}, %Estore.Resource{id: id, parent_id: parent_id}, state) do
    # {:calendar, _, [{type, entries}]} = Estore.ICS.decode_lines(state)
    current = Estore.Repo.get!(Estore.Calendar, id) |> Estore.Repo.preload(:root)

    Estore.Repo.update!(
      change(current, %{
        type: :unknown,
        root_id: find_root(parent_id),
        # Enum.map(entries, &Estore.ICS.encode_property/1)
        entries: state
      })
    )

    :ok
  end

  @impl true
  def read(%{}, %Estore.Resource{id: id}) do
    calendar = Estore.Repo.get!(Estore.Calendar, id)

    {:ok, _read(calendar)}
  end

  defp _read(calendar) do
    Enum.join(calendar.entries, "\r\n")
  end

  defp _read(calendar, start) do
    require Ecto.Query

    if calendar.type == :root do
      Enum.reduce(
        Ecto.Query.where(Estore.Calendar, root_id: ^calendar.id) |> Estore.Repo.all(),
        start,
        &_read(&1, &2)
      )
    else
      type_str = Estore.ICS.type2str(calendar.type)
      start ++ ["BEGIN:#{type_str}" | calendar.entries] ++ ["END:#{type_str}"]
    end
  end

  defp find_root(id) do
    case Estore.Repo.get(Estore.Calendar, id) do
      nil -> nil
      %{root_id: nil} -> id
      %{root_id: root} -> find_root(root)
    end
  end
end
