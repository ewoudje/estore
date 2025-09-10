defmodule EstoreWeb.Parsing.Propfind do
  @moduledoc """
  This module is responsible for parsing PROPFIND requests.
  """

  def xml({{"DAV:", "propfind"}, [], [{{"DAV:", "prop"}, [], properties}]}) do
    {:ok, Enum.map(properties, fn {e, _, _} -> e end)}
  end

  def xml(_) do
    {:error, "Invalid PROPFIND XML"}
  end
end
