defmodule Estore.ICS.Mapper do
  def decode(ics) when is_bitstring(ics) do
    decode(String.split(~r/(\r\n|\r|\n)/, trim: true))
  end

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

  defp decode_entries([{key, {args, value}} | tail], map) do
    decode_entries(tail, Map.put(map, key, {args, value}))
  end

  defp decode_entries([], map), do: map

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

  defp encode(str, [{k, {args, value}} | tail]) do
    encode(
      str <> k <> serialize_args(k, args) <> ":" <> serialize_value(k, args, value) <> "\r\n",
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

  # DATETIME
  defp parse_value(k, args, value) when k in ~w(COMPLETED DTEND DUE DTSTART) do
    with {:ok, r} =
           Estore.ICS.DateParser.parse_datetime(value, List.keyfind(args, "TZID", 0, nil)),
         do: r
  end

  defp parse_value(_, _, value), do: value
  defp parse_arg(_, _, value), do: value

  defp serialize_arg(_, _, value) when is_bitstring(value), do: value
  defp serialize_value(_, _, value) when is_bitstring(value), do: value
end
