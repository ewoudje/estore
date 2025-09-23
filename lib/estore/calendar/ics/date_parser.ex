defmodule Estore.ICS.DateParser do
  @moduledoc """
  Based from https://github.com/jonathanballs/magical/blob/main/lib/magical/parser/date_parser.ex

  Responsible for parsing datestrings in predefined formats into %DateTime{}
  structs. Valid formats are defined by the "Internet Calendaring and Scheduling
  Core Object Specification" (RFC 2445).

    - **Full text:**      http://www.ietf.org/rfc/rfc2445.txt
    - **DateTime spec:**  http://www.kanzaki.com/docs/ical/dateTime.html
    - **Date spec:**      http://www.kanzaki.com/docs/ical/date.html
  """

  def parse_datetime(value, tzid) do
    case {tzid, parse_string(value)} do
      {_, {:error, _} = e} ->
        e

      {_, {:ok, %Date{} = date}} ->
        NaiveDateTime.new(date, ~T[00:00:00])

      {{"TZID", v}, {:ok, %NaiveDateTime{} = naive}} ->
        DateTime.from_naive(naive, v)

      {_, dt} ->
        dt
    end
  end

  # Date Format: "19690620T201804Z"
  defp parse_string(<<_date::binary-size(8), "T", _time::binary-size(6), "Z">> = date_time) do
    with {:ok, naive_date_time} <- Timex.parse(date_time, "%Y%m%dT%H%M%SZ", :strftime),
         {:ok, date_time} <- DateTime.from_naive(naive_date_time, "Etc/UTC") do
      {:ok, DateTime.truncate(date_time, :second)}
    end
  end

  # Date Format: "19690620T201804"
  defp parse_string(<<_date::binary-size(8), "T", _time::binary-size(6)>> = date_time) do
    case Timex.parse(date_time, "%Y%m%dT%H%M%S", :strftime) do
      {:ok, naive_date_time} -> {:ok, NaiveDateTime.truncate(naive_date_time, :second)}
      e -> e
    end
  end

  # Date Format: "19690620"
  defp parse_string(<<_date::binary-size(8)>> = date_time) do
    with {:ok, naive_date_time} <- Timex.parse(date_time, "%Y%m%d", :strftime) do
      {:ok, NaiveDateTime.to_date(naive_date_time)}
    end
  end

  defp parse_string(_), do: {:error, :invalid_string}
end
