defmodule Estore.ICS do
  def ics2map(ics) do
    %{"VCALENDAR" => [cal]} = Estore.ICS.Mapper.decode(ics)
    cal
  end

  def map2ics(map) do
    Estore.ICS.Mapper.encode("BEGIN:VCALENDAR\r\n", Map.to_list(map)) <> "END:VCALENDAR\r\n"
  end

  def decode(ics), do: decode("VCALENDAR", ics2map(ics))

  def decode(type, map) when is_map(map) do
    id = Ecto.UUID.generate()

    Enum.reduce(map, [%{type: type, uuid: id}], fn
      {"VTIMEZONE", _}, x ->
        x

      {k, entries}, [m | tail] when is_list(entries) ->
        {refs, tail} =
          Enum.map_reduce(entries, tail, fn m, l ->
            [%{uuid: ref}] = i = decode(k, m)
            {ref, i ++ l}
          end)

        [Map.put(m, :refs, refs) | tail]

      {k, {args, v}}, [m | tail] ->
        [Map.put(m, k, [Enum.map(args, fn {k, v} -> [k, v] end), v]) | tail]
    end)
  end
end

# File.read!("test/icsexample1.ics") |> Estore.ICS.decode()
