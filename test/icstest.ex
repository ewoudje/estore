defmodule Estore.ICS.Mapper do
  def decode(ics) do
    ics
    |> String.split(~r/(\r\n|\r|\n)/, trim: true)
    |> Enum.map(&String.split(&1, ":"))
    |> Enum.map(fn [key, value] ->
      [key | args] = String.split(key, ";")
      key = String.upcase(key)

      args =
        Enum.map(args, fn a ->
          [k, v] = String.split(a, "=")
          {k, parse_arg(key, k, v)}
        end)

      {key,
       {
         args,
         parse_value(key, args, value)
       }}
    end)
    |> decode_entries(%{})
  end

  defp decode_entries([{"BEGIN", {[], type}} | tail], map) do
    {within, rest, ^type} = decode_entries(tail, %{})
    decode_entries(rest, Map.put(map, type, [within | Map.get(map, type, [])]))
  end

  defp decode_entries([{"END", {[], type}} | tail], map), do: {map, tail, type}

  defp decode_entries([{key, {args, value}} | tail], map) do
    decode_entries(tail, Map.put(map, key, {args, value}))
  end

  defp decode_entries([], map), do: map

  # DATETIME
  defp parse_value(k, args, value) when k in ~w(COMPLETED DTEND DUE DTSTART) do
    # Estore.ICS.DateParser.parse_datetime(value, List.keyfind(args, "TZID", 0, nil))
    value
  end

  defp parse_value(_, _, value), do: value
  defp parse_arg(_, _, value), do: value
end

defmodule Estore.ICS do
  def decode(str) when is_bitstring(str) do
    Estore.ICS.Mapper.decode(str) |> decode()
  end

  def decode(%{"VCALENDAR" => [cal]}) do
    cal
  end

  def encode(map) do
    encode("BEGIN:VCALENDAR\r\n", Map.to_list(map)) <> "END:VCALENDAR\r\n"
  end

  defp encode(str, [{k, {args, value}} | tail]) do
    encode(
      str <> k <> serialize_args(k, args) <> ":" <> serialize_value(k, args, value) <> "\r\n",
      tail
    )
  end

  defp encode(str, [{type, lst} | tail]) when is_list(lst) do
    encode(
      Enum.reduce(lst, str, fn x, s ->
        encode(
          s <> "BEGIN:" <> type <> "\r\n",
          Map.to_list(x)
        ) <> "END:" <> type <> "\r\n"
      end),
      tail
    )
  end

  defp encode(str, []), do: str

  defp serialize_args(_, []), do: ""

  defp serialize_args(key, args),
    do:
      ";" <>
        (args
         |> Enum.map(fn {k, v} -> k <> "=" <> serialize_arg(key, k, v) end)
         |> Enum.join(";"))

  defp serialize_arg(_, _, value) when is_bitstring(value), do: value
  defp serialize_value(_, _, value) when is_bitstring(value), do: value
end

IO.inspect(
  Estore.ICS.decode(
    Estore.ICS.encode(
      Estore.ICS.decode("""
      BEGIN:VCALENDAR
      VERSION:2.0
      CALSCALE:GREGORIAN
      BEGIN:VEVENT
      SUMMARY:Access-A-Ride Pickup
      DTSTART;TZID=America/New_York:20130802T103400
      DTEND;TZID=America/New_York:20130802T110400
      LOCATION:1000 Broadway Ave.\, Brooklyn
      DESCRIPTION: Access-A-Ride trip to 900 Jay St.\, Brooklyn
      STATUS:CONFIRMED
      SEQUENCE:3
      END:VEVENT
      BEGIN:VEVENT
      SUMMARY:Access-A-Ride Pickup
      DTSTART;TZID=America/New_York:20130802T200000
      DTEND;TZID=America/New_York:20130802T203000
      LOCATION:900 Jay St.\, Brooklyn
      DESCRIPTION: Access-A-Ride trip to 1000 Broadway Ave.\, Brooklyn
      STATUS:CONFIRMED
      SEQUENCE:3
      END:VEVENT
      END:VCALENDAR
      """)
    )
  )
)
