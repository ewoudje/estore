defmodule Estore.Propfind do
  def get(resource, properties, depth) do
    Enum.map(Estore.Resource.get_family(resource, depth), &propfind(&1, properties))
  end

  def propfind(resource, properties) do
    found = fetch_props(resource, properties)

    missing =
      properties
      |> Enum.filter(fn {namespace, name} ->
        !Enum.any?(found, fn {{namespace2, localname2}, _, _} ->
          namespace2 == namespace and localname2 == name
        end)
      end)
      |> Enum.map(fn {namespace, name} -> {{namespace, name}, [], []} end)

    propfinds =
      cond do
        missing == [] ->
          [{:propstat, :ok, found}]

        found == [] ->
          [{:propstat, :not_found, missing}]

        true ->
          [{:propstat, :ok, found}, {:propstat, :not_found, missing}]
      end

    {:response, resource, propfinds}
  end

  defp fetch_props(resource, properties) do
    Sentry.Context.add_breadcrumb(%{
      category: "estore.propfind.fetch_props",
      message: "fetching properties",
      level: :debug,
      data: {resource, properties}
    })

    process_properties(
      Estore.Extension.apply_for_properties(:properties, resource, properties)
      |> Enum.filter(fn
        :not_found -> false
        _ -> true
      end)
    )
  end

  defp process_properties(fetched_properties) do
    map =
      Enum.reduce(fetched_properties, %{}, fn
        {e, {:value, value}, _}, acc when is_list(value) ->
          Map.put(acc, e, value)

        {e, {:value, value}, _}, acc ->
          Map.put(acc, e, [value])

        {e, {:append, value}, _}, acc ->
          Map.put(acc, e, [value | Map.get(acc, e, [])])

        {e, {:empty}, _}, acc ->
          Map.put_new(acc, e, [])

        {e, :not_found, _}, acc ->
          acc
      end)

    Enum.map(map, fn
      {pair, v} -> {pair, [], v}
    end)
  end
end
