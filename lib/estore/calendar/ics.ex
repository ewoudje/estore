defmodule Estore.ICS do
  def encode(components) do
    ics_content = """
    BEGIN:VCALENDAR
    VERSION:2.0
    PRODID:-//Estore//NONSGML v1.0//EN
    #{Enum.map(components, &encode_component/1) |> Enum.join("\n")}
    END:VCALENDAR
    """
  end

  def encode_component({:event, properties}) do
    """
    BEGIN:VEVENT
    #{Enum.join(properties, "\n")}
    END:VEVENT
    """
  end

  def encode_property({key, attribs, value}) do
    key = String.upcase(key)
    attribs = Enum.map(attribs, fn {k, v} -> "#{k}=#{v}" end) |> Enum.join(";")

    if attribs == "" do
      "#{key}: #{value}"
    else
      "#{key};#{attribs}: #{value}"
    end
  end

  def into_lines(str) do
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
    |> tl()
  end

  def decode_lines(lines, opts \\ %{}) do
    decode_calendar(lines, opts)
  end

  defp decode_calendar(["BEGIN:VCALENDAR", prodid, "VERSION:2.0" | components], opts) do
    {components, ["END:VCALENDAR"]} = decode_component(components, opts)
    {:calendar, prodid, components}
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

    {key,
     Enum.map(attribs, fn attrib ->
       [k, v] = String.split(attrib, "=")
       {k, v}
     end), String.trim(value)}
  end

  def type2str(value) do
    case value do
      :event -> "VEVENT"
      :to_do -> "VTODO"
      :journal -> "VJOURNAL"
      :free_busy -> "VFREEBUSY"
      :time_zone -> "VTIMEZONE"
      _ -> "UNKNOWN"
    end
  end
end
