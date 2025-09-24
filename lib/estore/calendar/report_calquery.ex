defmodule Estore.Report.CalQuery do
  use Estore.Report
  @ns "urn:ietf:params:xml:ns:caldav"

  @impl true
  def root(), do: {@ns, "calendar-query"}

  @impl true
  def report(resource, {{@ns, "calendar-query"}, _, contents}, depth) do
    {_, _, filters} = List.keyfind(contents, {@ns, "filter"}, 0, {nil, nil, []})
    {_, _, properties} = List.keyfind(contents, {"DAV:", "prop"}, 0)

    {:ok, filtered} = filter_resources(resource, filters, depth)
    procure(resource, filtered, Enum.map(properties, fn {e, _, _} -> e end))
  end

  defp filter_resources(resource, [], depth) do
    {:ok, Estore.Resource.get_family(resource, depth)}
  end

  defp filter_resources(resource, filters, depth) do
    results =
      Estore.Resource.get_family(resource, depth)
      |> Enum.map(&{&1, Estore.Repo.get!(Estore.Calendar, &1.id).entries})
      |> Enum.map(&{&1, filters_resource(&1, filters)})

    error =
      Enum.find(results, fn
        {_, {:error, _}} -> true
        {_, _} -> false
      end)

    if error do
      {_, error} = error
      error
    else
      {:ok, Enum.filter_map(results, fn {_, {:ok, v}} -> v end, fn {{r, _}, _} -> r end)}
    end
  end

  defp filters_resource(resource, [filter | tail]) do
    case filter_resource(resource, filter) do
      {:ok, true} -> {:ok, true}
      {:ok, false} -> filters_resource(resource, tail)
      {:error, e} -> {:error, e}
    end
  end

  defp filters_resource(_resource, []) do
    {:ok, false}
  end

  # TODO CALDAV:time-range
  defp filter_resource({resource, entries}, {{@ns, "comp-filter"}, attr, children}) do
    {"name", name} = List.keyfind(attr, "name", 0, {"name", false})

    if name do
      inside =
        entries
        |> Enum.drop_while(&(!(String.ends_with?(&1, name) && String.starts_with?(&1, "BEGIN:"))))
        |> Enum.take_while(&(!(String.ends_with?(&1, name) && String.starts_with?(&1, "END:"))))

      result =
        case {children, inside} do
          {_, []} -> {:ok, false}
          {[], _} -> {:ok, true}
          # Remove BEGIN:xxxx
          {_, [_ | rest]} -> filters_resource({resource, rest}, children)
        end

      case {result, should_inverse?(children)} do
        {{:ok, v}, true} -> {:ok, !v}
        {{:ok, v}, false} -> {:ok, v}
        {{:error, e}, _} -> {:error, e}
      end
    else
      {:error, {:missing_attribute, :comp_filter_name}}
    end
  end

  defp filter_resource({resource, entries}, {{@ns, "prop-filter"}, attr, children}) do
    {:error, :unimplemented}
  end

  defp should_inverse?(children) do
    Enum.any?(children, fn
      {{@ns, "is-not-defined"}, _, _} -> true
      _ -> false
    end)
  end

  defp procure(%{collection: false, fqn: fqn} = resource, [%{fqn: fqn2}], properties)
       when fqn2 == fqn,
       do: Estore.Propfind.propfind(resource, properties)

  defp procure(%{fqn: fqn} = resource, resources, properties) do
    if Enum.any?(resources, fn
         %Estore.Resource{fqn: fqn2} ->
           not String.starts_with?(fqn2, fqn)

         _ ->
           true
       end) do
      [{:response, resource, {:propstat, :bad_input, []}}]
    else
      Enum.map(resources, &Estore.Propfind.propfind(&1, properties))
    end
  end
end
