defmodule Estore.Calendar do
  use Estore.Source
  use Ecto.Schema
  import Ecto.Changeset

  @ns "urn:ietf:params:xml:ns:caldav"

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "calendar_resources" do
    field(:type, Ecto.Enum, values: [:unknown, :root])
    field(:contents, :map)
    belongs_to(:root, Estore.Calendar, type: Ecto.UUID)
  end

  @doc false
  def changeset(calendar, attrs) do
    calendar
    |> cast(attrs, [:type, :contents, :root_id])
    |> cast_assoc(:root)
    |> validate_required([:type, :contents])
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
        if f.type == :root do
          :not_found
        else
          {:ok, r} = _read(f)
          {:value, r}
        end

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
      type: :unknown,
      root: nil,
      contents: %{}
    })

    :ok
  end

  def configure_calendar_root(%Estore.Resource{id: id}) do
    Estore.Repo.update!(Ecto.Changeset.change(%Estore.Calendar{id: id}, type: :root))
  end

  @impl true
  def write(%{}, %Estore.Resource{id: id}, binary, state) do
    state = state || []
    lines = String.split(binary, ~r/(\r\n|\r|\n)/, trim: true)
    {:ok, state ++ lines}
  end

  @impl true
  def finish_write(%{}, %Estore.Resource{id: root_id, owner_id: owner_id} = r, state) do
    Estore.Repo.transact(fn ->
      root = Estore.Repo.get!(Estore.Calendar, root_id)

      for {id, %{type: t} = m} <- IO.inspect(Estore.ICS.decode(state)) do
        if t != "VCALENDAR" do
          id = Map.get(m, "UID", id)

          if Estore.Repo.get(Estore.Resource, id) == nil do
            Estore.Resource.create(r, id <> ".ics", false,
              id: id,
              owner_id: owner_id,
              source: source()
            )
          end

          Estore.Repo.update!(
            change(Estore.Repo.get!(Estore.Calendar, id) |> Estore.Repo.preload(:root), %{
              id: id,
              type: :unknown,
              root: root,
              contents: m2json(m, id)
            })
          )
        end
      end

      {:ok, nil}
    end)

    :ok
  end

  @impl true
  def read(%{}, %Estore.Resource{id: id}) do
    calendar = Estore.Repo.get!(Estore.Calendar, id)

    _read(calendar)
  end

  defp _read(calendar) do
    Estore.Repo.transact(fn ->
      resource =
        Estore.ICS.encode_(
          &json2m(Estore.Repo.get!(Estore.Calendar, &1).contents, &1),
          calendar.id
        )

      type = calendar.contents["type"]

      {:ok,
       Estore.ICS.map2ics(%{
         type => [resource],
         "PRODID" => {[], "//ewoudje.com/ESTORE V1//EN"},
         "VERSION" => {[], "2.0"},
         "CALSCALE" => {[], "GREGORIAN"}
       })}
    end)
  end

  defp find_root(id) do
    case Estore.Repo.get(Estore.Calendar, id) do
      nil -> nil
      %{root_id: nil} -> id
      %{root_id: root} -> find_root(root)
    end
  end

  def child_source(_) do
    source()
  end

  defp m2json(map, id),
    do:
      Map.new(
        map
        |> Enum.filter(fn
          {"UID", _} -> false
          _ -> true
        end)
        |> Enum.map(fn
          {k, {args, v}} ->
            {k, [Enum.map(args, fn {k, v} -> [k, v] end), v]}

          a ->
            a
        end)
      )

  defp json2m(map, id) do
    Map.new(map, fn
      {"refs", v} ->
        {:refs, v}

      {"type", v} ->
        {:type, v}

      {k, [args, v]} when k in ~w(COMPLETED DTEND DUE DTSTART) ->
        {:ok, dt, _} = DateTime.from_iso8601(v)
        {k, {Enum.map(args, fn [k, v] -> {k, v} end), dt}}

      {k, [args, v]} ->
        {k, {Enum.map(args, fn [k, v] -> {k, v} end), v}}
    end)
    |> Map.put("UID", id)
  end
end
