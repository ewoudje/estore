defmodule Estore.ICS do
  def decode(str, opts \\ {}) do
    ["" | lines] =
      str
      |> String.split(~r/(\r\n|\r|\n)/)
      |> Enum.chunk_while(
        [],
        &if &1 =~ ~r/^\s.*$/ do
          {:cont, [&1 | &2]}
        else
          {:cont, &2, [&1]}
        end,
        &{:cont, &1}
      )
      |> Enum.map(&Enum.join(Enum.reverse(&1)))

    decode_calendar(lines, opts)
  end

  defp format_datetime(datetime) do
    datetime
    |> DateTime.to_iso8601()
    |> String.replace(":", "")
    |> String.replace("-", "")
  end

  defp decode_calendar(["BEGIN:VCALENDAR", "VERSION:2.0", prodid | components], opts) do
    {components, ["END:VCALENDAR"]} = decode_component(components, opts)
    {:calendar, prodid, components}
  end

  defp decode_component(["BEGIN:VEVENT" | tail], opts) do
    {event, tail} = decode_event(tail, opts)
    {components, tail} = decode_component(tail, opts)
    {[event | components], tail}
  end

  defp decode_component(lse, opts) do
    {[], lse}
  end

  defp decode_event(["END:VEVENT" | tail], opts, result) do
    {{:event, result}, tail}
  end

  defp decode_event([value | tail], opts, result \\ []) do
    decode_event(tail, opts, [decode_property(value) | result])
  end

  defp decode_property(value) do
    [key, value] = String.split(value, ":")
    [key | attribs] = String.split(key, ";")
    {key, attribs, value}
  end
end

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
|> IO.inspect()
