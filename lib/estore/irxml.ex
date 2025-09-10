defmodule Estore.XML.IR do
  @d "DAV:"

  @type status() :: :ok | :created | :deleted | :not_found | :failed_dependency
  @type ir() ::
          {:multistatus, [ir()]}
          | {:response, Estore.Resource.t(), [ir()]}
          | {:propstat, status(), [ir()]}
          | {:href, Estore.Resource.t()}
          | {{String.t(), String.t()}, Estore.XML.attributes(), [ir()]}
          | String.t()

  @spec ir2xml(ir(), map()) :: Estore.XML.t()
  def ir2xml({:multistatus, values}, opts) do
    {{@d, "multistatus"}, [], Enum.map(values, &ir2xml(&1, opts))}
  end

  def ir2xml({:response, resource, values}, opts) do
    {{@d, "response"}, [],
     [
       ir2xml({:href, resource}, opts)
       | Enum.map(values, &ir2xml(&1, opts))
     ]}
  end

  def ir2xml({:propstat, status, values}, opts) do
    {{@d, "propstat"}, [],
     [
       {{@d, "status"}, [], [status2str(status)]},
       {{@d, "prop"}, [], Enum.map(values, &ir2xml(&1, opts))}
     ]}
  end

  def ir2xml({:href, resource}, %{href_uuid: true}) do
    {{@d, "href"}, [{"type", "uuid"}], [resource.id]}
  end

  def ir2xml({:href, nil}, _) do
    ""
  end

  def ir2xml({:href, resource}, _) do
    {{@d, "href"}, [], [Estore.Resource.get_href(resource)]}
  end

  def ir2xml({{namespace, localname}, attribs, values}, opts) when is_list(values) do
    {{namespace, localname}, attribs, Enum.map(values, &ir2xml(&1, opts))}
  end

  def ir2xml(str, _) when is_bitstring(str) do
    str
  end

  def ir2xml(unknown, _) do
    "#{unknown}"
  end

  @spec xml2ir(Estore.XML.t(), map()) :: ir()
  def xml2ir({{"DAV:", "href"}, [{"type", "uuid"}], [str]}, opts) when is_bitstring(str) do
    {:href, Estore.Repo.get(Estore.Resource, str)}
  end

  def xml2ir({{"DAV:", "href"}, attribs, [str]}, opts) when is_bitstring(str) do
    {:href, Estore.Resource.get_by_path(str)}
  end

  def xml2ir({{namespace, localname}, attribs, values}, opts) when is_list(values) do
    {{namespace, localname}, attribs, Enum.map(values, &xml2ir(&1, opts))}
  end

  def xml2ir(str, _) when is_bitstring(str) do
    str
  end

  def xml2ir({:cdata, str}, _) do
    # TODO?
    str
  end

  defp status2str(:ok), do: "HTTP/1.1 200 OK"
  defp status2str(:created), do: "HTTP/1.1 201 Created"
  defp status2str(:deleted), do: "HTTP/1.1 204 No Content"
  defp status2str(:not_found), do: "HTTP/1.1 404 Not Found"
  defp status2str(:failed_dependency), do: "HTTP/1.1 424 Failed Dependency"
  defp status2str(:bad_input), do: "HTTP/1.1 400 Bad Request"
end
