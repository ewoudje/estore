defmodule Estore.ICS.Mapper do
  def decode(ics) when is_bitstring(ics) do
    decode(String.split(ics, ~r/(\r\n|\r|\n)/, trim: true))
  end

  # TODO handle ,DESCRIPTION;ALTREP="data:text/html,Yes":Yes,
  def decode(ics) when is_list(ics) do
    ics
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

  defp decode_entries([{"UID", {[], v}} | tail], map),
    do: decode_entries(tail, Map.put(map, "UID", v))

  defp decode_entries([{key, {args, value}} | tail], map) do
    decode_entries(tail, Map.put(map, key, {args, value}))
  end

  defp decode_entries([], map), do: map

  def encode(str, map) when is_map(map) do
    encode(str, Map.to_list(map))
  end

  def encode(str, [{type, lst} | tail]) when is_list(lst) and is_bitstring(type) do
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

  def encode(str, [{k, {args, value}} | tail]) when is_bitstring(k) do
    encode(
      str <> k <> serialize_args(k, args) <> ":" <> serialize_value(k, args, value) <> "\r\n",
      tail
    )
  end

  def encode(str, [{"UID", id} | tail]), do: encode(str <> "UID:" <> id <> "\r\n", tail)
  def encode(str, [{k, _} | tail]) when is_atom(k), do: encode(str, tail)
  def encode(str, []), do: str

  defp serialize_args(_, []), do: ""

  defp serialize_args(key, args),
    do:
      ";" <>
        (args
         |> Enum.map(fn {k, v} -> k <> "=" <> serialize_arg(key, k, v) end)
         |> Enum.join(";"))

  # DATETIME
  defp parse_value(k, args, value) when k in ~w(COMPLETED DTEND DUE DTSTART) do
    with {:ok, r} =
           Estore.ICS.DateParser.parse_datetime(value, List.keyfind(args, "TZID", 0, nil)),
         do: r
  end

  defp parse_value(_, _, value), do: value
  defp parse_arg(_, _, value), do: value

  defp serialize_value(_, _, %NaiveDateTime{} = d),
    do: NaiveDateTime.to_iso8601(d, :basic)

  defp serialize_value(_, args, %DateTime{} = d),
    do:
      NaiveDateTime.to_iso8601(
        if List.keymember?(args, "TZID", 0) do
          {"TZID", tz} = List.keyfind!(args, "TZID", 0)
          DateTime.shift_zone!(d, tz)
        else
          d
        end,
        :basic
      )

  defp serialize_value(_, _, value) when is_bitstring(value), do: value
  defp serialize_arg(_, _, value) when is_bitstring(value), do: value
end
