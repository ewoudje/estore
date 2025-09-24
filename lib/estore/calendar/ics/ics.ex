defmodule Estore.ICS do
  def ics2map(ics) do
    %{"VCALENDAR" => [cal]} = Estore.ICS.Mapper.decode(ics)
    cal
  end

  def map2ics(map) do
    Estore.ICS.Mapper.encode("BEGIN:VCALENDAR\r\n", map) <> "END:VCALENDAR\r\n"
  end

  def decode(ics), do: decode("VCALENDAR", ics2map(ics))

  def decode(type, contents, id \\ Ecto.UUID.generate())
      when is_map(contents) do
    id = Map.get(contents, "UID", id)

    Enum.reduce(contents, %{id => %{:type => type, "UID" => id}}, fn
      {"VTIMEZONE", _}, x ->
        x

      {k, entries}, m when is_list(entries) ->
        {refs, m} =
          Enum.map_reduce(entries, m, fn entry_contents, m ->
            new_id = Map.get(entry_contents, "UID", Ecto.UUID.generate())
            {new_id, Map.merge(m, decode(k, entry_contents, new_id))}
          end)

        Map.replace_lazy(m, id, &Map.put(&1, :refs, refs ++ Map.get(&1, :refs, [])))

      {k, v}, m ->
        Map.replace_lazy(m, id, &Map.put(&1, k, v))
    end)
  end

  def encode(store, id) do
    map2ics(encode_(store, id))
  end

  def encode_(store, id) do
    value = store.(id)

    Enum.reduce(Map.get(value, :refs, []), value, fn ref_id, m ->
      v = encode_(store, ref_id)
      Map.put(m, v.type, [v | Map.get(m, v.type, [])])
    end)
  end
end

# a = File.read!("test/icsexample1.ics") |> Estore.ICS.decode()
# Estore.ICS.encode(&a[&1],
