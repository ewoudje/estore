defmodule EstoreWeb.Parsing.Proppatch do
  @moduledoc """
  This module is responsible for parsing PROPFIND requests.
  """

  def xml({{"DAV:", "propertyupdate"}, [], contents}) do
    setters = Enum.flat_map(contents, &get_setters/1)
    removers = Enum.flat_map(contents, &get_removers/1)

    {:ok, setters, removers}
  end

  defp get_setters({{"DAV:", "set"}, [], [{{"DAV:", "prop"}, [], properties}]}) do
    properties
  end

  defp get_removers({{"DAV:", "remove"}, [], [{{"DAV:", "prop"}, [], properties}]}) do
    properties
  end

  defp get_setters(_), do: []
  defp get_removers(_), do: []

  def xml(_) do
    {:error, "Invalid PROPFIND XML"}
  end
end
