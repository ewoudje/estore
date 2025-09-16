defmodule Estore.XML do
  @behaviour Saxy.Handler

  @type namespace() :: String.t()
  @type element_name() :: {namespace(), String.t()}
  @type attributes() :: [{String.t(), String.t()}]
  @type t() :: {element_name(), attributes(), [t()]} | String.t() | {:cdata, String.t()}

  def decode(str, opts \\ %{}) do
    :telemetry.span([:xml, :decode], %{opts: opts}, fn ->
      {:ok, xml} = Saxy.parse_string(str, __MODULE__, nil)
      {Estore.XML.IR.xml2ir(xml, opts), %{}}
    end)
  end

  def encode(ir, opts \\ %{}) do
    :telemetry.span([:xml, :encode], %{opts: opts}, fn ->
      xml = Estore.XML.IR.ir2xml(ir, opts)

      {{name, attributes, content}, {_, namespaces}} =
        denamespace(xml, {0, %{}})

      attributes = Enum.map(namespaces, fn {k, v} -> {"xmlns:" <> v, k} end)

      {Saxy.encode!({name, attributes, content}, []), %{namespaces: namespaces}}
    end)
  end

  @impl true
  def handle_event(:start_document, prolog, _) do
    {:ok, {[], []}}
  end

  @impl true
  def handle_event(:end_document, _data, {[result], namespaces}) do
    if :ets.whereis(:xml_namespaces) == :undefined do
      :ets.new(:xml_namespaces, [:set, :public, :named_table])
    end

    :ets.insert_new(
      :xml_namespaces,
      Enum.flat_map(namespaces, fn {_, lst} ->
        Enum.map(lst, &{&1 |> elem(1), &1 |> elem(0)})
      end)
    )

    {:ok, result}
  end

  @impl true
  def handle_event(
        :start_element,
        {name, attributes},
        {lst, namespaces}
      ) do
    new_namespaces =
      attributes
      |> Enum.filter(fn {k, _} -> String.starts_with?(k, "xmlns:") end)
      |> Enum.map(fn {k, v} ->
        {String.replace(k, "xmlns:", ""), v}
      end)

    {"xmlns", ns} = Enum.find(attributes, {"xmlns", nil}, fn {k, _} -> k == "xmlns" end)
    namespaces = [{ns, new_namespaces} | namespaces]

    {:ok,
     {
       [
         {
           ns_name(name, namespaces),
           Enum.filter(attributes, fn {k, _} -> !String.starts_with?(k, "xmlns") end),
           []
         }
         | lst
       ],
       namespaces
     }}
  end

  @impl true
  def handle_event(
        :end_element,
        name,
        {[content, parent | lst], [_ | namespaces]}
      ) do
    {name, attributes, contents} = parent

    {:ok,
     {[
        {name, attributes, [content | contents]}
        | lst
      ], namespaces}}
  end

  @impl true
  def handle_event(
        :end_element,
        name,
        {[last], ns}
      ) do
    {:ok, {[last], ns}}
  end

  @impl true
  def handle_event(:characters, chars, {[{name, attributes, contents} | lst], namespaces} = state) do
    trimmed = String.trim(chars)

    if trimmed == "" do
      {:ok, state}
    else
      {:ok, {[{name, attributes, [trimmed | contents]} | lst], namespaces}}
    end
  end

  @impl true
  def handle_event(:cdata, cdata, {[{name, attributes, contents} | lst], namespaces}) do
    {:ok, {[{name, attributes, [{:cdata, cdata} | contents]} | lst], namespaces}}
  end

  defp ns_name(name, namespaces) do
    if String.contains?(name, ":") do
      [ns, name] = String.split(name, ":", parts: 2)
      {ns_name2(ns, namespaces), name}
    else
      {default_namespace(namespaces), name}
    end
  end

  defp ns_name2(ns_name, [{_, lst} | tail]) do
    found = List.keyfind(lst, ns_name, 0)

    if found do
      found |> elem(1)
    else
      ns_name2(ns_name, tail)
    end
  end

  defp ns_name2(ns_name, []), do: raise("No namespace found for #{ns_name}")

  defp default_namespace([{default, _} | tail]) do
    if default do
      default
    else
      default_namespace(tail)
    end
  end

  defp default_namespace([]) do
    ""
  end

  defp denamespace({{ns, name}, attributes, content}, {idx, namespaces} = nstuple)
       when is_list(content) and is_map_key(namespaces, ns) do
    prefix = Map.get(namespaces, ns)
    denamespace2(prefix, name, attributes, content, nstuple)
  end

  defp denamespace({{ns, name}, attributes, content}, {idx, namespaces})
       when is_list(content) do
    prefix = decide_prefix(ns)

    idx = idx + 1
    namespaces = Map.put(namespaces, ns, prefix)

    denamespace2(prefix, name, attributes, content, {idx, namespaces})
  end

  defp denamespace(str, rest) when is_bitstring(str), do: {str, rest}

  defp denamespace2(prefix, name, attributes, content, nstuple) do
    processed = Enum.map(content, &denamespace(&1, nstuple))

    nstuple =
      Enum.reduce(processed, nstuple, fn {_, {i, ns}}, {i2, ns2} ->
        {max(i, i2), Map.merge(ns, ns2)}
      end)

    content = Enum.map(processed, &elem(&1, 0))

    {{prefix <> ":" <> name, attributes, content}, nstuple}
  end

  defp decide_prefix(ns) do
    case :ets.lookup(:xml_namespaces, ns) do
      [{^ns, prefix}] ->
        prefix

      [] ->
        new_prefix = "ns" <> Integer.to_string(:ets.info(:xml_namespaces, :size) + 1)
        :ets.insert(:xml_namespaces, {ns, new_prefix})
        new_prefix
    end
  end

  defp prefix2ns(prefix) do
    case prefix do
      "CS" ->
        "http://calendarserver.org/ns/"

      "C" ->
        "urn:ietf:params:xml:ns:caldav"

      "D" ->
        "DAV:"

      "E" ->
        "https://ewoudje.com/ns"

      _ ->
        nil
    end
  end
end
