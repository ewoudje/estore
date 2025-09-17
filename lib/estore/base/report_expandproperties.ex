defmodule Estore.Report.ExpandProperties do
  use Estore.Report

  @impl true
  def root(), do: {"DAV:", "expand-property"}

  @impl true
  def report(resource, {{"DAV:", "expand-property"}, _, contents}, _) do
    properties(resource, contents)
  end

  defp properties(resource, contents) do
    properties =
      Enum.map(contents, fn
        {{"DAV:", "property"}, [{"name", name}, {"namespace", namespace}], contents} ->
          {{namespace, name}, contents}

        {{"DAV:", "property"}, [{"name", name}], contents} ->
          {{"DAV:", name}, contents}

        _ ->
          :bad_input
      end)

    {:response, _, stats} =
      Estore.Propfind.propfind(resource, Enum.map(properties, &elem(&1, 0)))

    [{:response, resource, Enum.map(stats, &propstat(&1, properties))}]
  end

  defp propstat(stats, contents) do
    case stats do
      {:propstat, :ok, statcontent} ->
        {:propstat, :ok,
         Enum.map(statcontent, fn {pair, _, _} = c ->
           continue_hrefs(c, elem(List.keyfind(contents, pair, 0), 1))
         end)}

      a ->
        a
    end
  end

  defp property(resource, []) do
    Estore.Propfind.propfind(resource, [])
  end

  defp continue_hrefs({:href, resource}, contents) do
    properties(resource, contents)
  end

  defp continue_hrefs({name, attribs, childs}, contents) when is_list(childs) do
    {name, attribs, Enum.map(childs, &continue_hrefs(&1, contents))}
  end

  defp continue_hrefs({name, attribs, value}, contents) when is_bitstring(value) do
    value
  end

  defp continue_hrefs(str, contents) when is_bitstring(str) do
    str
  end
end
