defmodule Estore.Report.Multiget do
  use Estore.Report
  @ns "urn:ietf:params:xml:ns:caldav"

  @impl true
  def root(), do: {@ns, "calendar-multiget"}

  @impl true
  def report(resource, {{@ns, "calendar-multiget"}, _, contents}) do
    hrefs =
      Enum.filter(contents, fn
        {:href, _} -> true
        _ -> false
      end)

    [{_, _, properties}] =
      Enum.filter(contents, fn
        {{"DAV:", "prop"}, _, _} -> true
        _ -> false
      end)

    procure(resource, hrefs, Enum.map(properties, fn {e, _, _} -> e end))
  end

  defp procure(%{collection: false, fqn: fqn} = resource, [href], properties) when href == fqn,
    do: Estore.Propfind.propfind(resource, properties)

  defp procure(%{fqn: fqn} = resource, hrefs, properties) do
    if Enum.any?(hrefs, fn
         {:href, %Estore.Resource{fqn: fqn2}} ->
           not String.starts_with?(fqn2, fqn)

         _ ->
           true
       end) do
      [{:response, resource, {:propstat, :bad_input, []}}]
    else
      Enum.map(hrefs, &Estore.Propfind.propfind(elem(&1, 1), properties))
    end
  end
end
