defmodule EstoreWeb.Dav do
  @moduledoc """
  This module is responsible for handling WebDAV requests.
  """

  alias Plug.Conn
  @behaviour Plug
  @methods ~w(PROPFIND PROPPATCH GET HEAD POST DELETE PUT COPY MOVE MKCOL REPORT)

  @impl true
  def init(opts) do
  end

  @impl true
  def call(
        %{
          method: method,
          body_params: %Plug.Conn.Unfetched{}
        } = conn,
        options
      )
      when method in @methods do
    :telemetry.span([:estore, :dav], %{method: method}, fn ->
      {case method do
         "PROPFIND" ->
           conn
           |> get_xml()
           |> get_resource()
           |> get_depth()
           |> if_set_send()

         "MKCOL" ->
           conn
           |> get_parent()
           |> no_resource()
           |> if_set_send()

         "PUT" ->
           conn
           |> get_resource(true)
           |> get_parent()
           |> if_set_send()

         "HEAD" ->
           conn
           |> get_resource()
           # |> handle_etag()
           |> if_set_send()

         "GET" ->
           conn
           |> get_resource()
           # |> handle_etag()
           |> if_set_send()

         "DELETE" ->
           conn
           |> get_resource()
           |> if_set_send()

         "COPY" ->
           conn
           |> get_resource()
           |> get_depth()
           |> get_destination()
           |> if_set_send()

         "MOVE" ->
           conn
           |> get_resource()
           |> get_depth()
           |> get_destination()
           |> if_set_send()

         "PROPPATCH" ->
           conn
           |> get_xml()
           |> get_resource()
           |> if_set_send()

         "REPORT" ->
           conn
           |> get_xml()
           |> get_depth()
           |> get_resource()
           |> if_set_send()

         _ ->
           conn
       end, %{}}
    end)
  end

  defp get_xml(conn) do
    header = List.keyfind(conn.req_headers, "content-type", 0)

    if header do
      {"content-type", content_type} = header
      {:ok, type, "xml", params} = Conn.Utils.content_type(content_type)
      # TODO if not xml Conn.send_resp(conn, 415, "Unsupported Media Type")

      {:ok, body, conn} = Conn.read_body(conn)
      EstoreWeb.RequestBodyLogging.request_body(body, conn)

      case Estore.XML.decode(body) do
        {:ok, xml} -> %{conn | body_params: xml, params: Map.put(conn.params, :xml, xml)}
        {:error, e} -> Conn.resp(conn, 400, "XML Parsing failed: #{inspect(e.reason)}")
      end
    else
      Conn.resp(conn, 400, "Bad Request: Expected a Content-Type")
    end
  end

  defp get_resource(conn, optional \\ false) do
    resource =
      Estore.Repo.get_by(Estore.Resource, fqn: Estore.Resource.get_fqn(conn.request_path))

    if !optional && resource == nil do
      Conn.resp(conn, 404, "Resource not found")
    else
      conn =
        if resource do
          Conn.put_resp_header(conn, "content-location", Estore.Resource.get_href(resource))
        else
          conn
        end

      %{conn | params: Map.put(conn.params, :resource, resource)}
    end
  end

  defp no_resource(conn) do
    conn = get_resource(conn, true)

    if conn.params.resource do
      Conn.resp(conn, 409, "Resource already exists")
    else
      conn
    end
  end

  defp get_depth(conn) do
    {"depth", depth} = List.keyfind(conn.req_headers, "depth", 0, {"depth", "0"})

    %{
      conn
      | params:
          Map.put(
            conn.params,
            :depth,
            case depth do
              "0" -> :zero
              "1" -> :one
              "infinity" -> :infinity
              _ -> :infinity
            end
          )
    }
  end

  defp get_parent(conn) do
    if conn.request_path == "/" do
      %{conn | params: Map.put(conn.params, :parent, nil)}
    else
      parent = Estore.Resource.get_parent(conn.request_path)

      if parent == nil do
        Conn.resp(conn, 404, "Parent not found")
      else
        %{conn | params: Map.put(conn.params, :parent, parent)}
      end
    end
  end

  defp get_destination(conn) do
    destination = List.keyfind(conn.req_headers, "destination", 0, nil)

    if destination do
      destination = Estore.Resource.get_fqn(elem(destination, 1))
      resource = Estore.Repo.get_by(Estore.Resource, fqn: destination)

      if resource do
        Conn.resp(conn, 409, "Destination already exists")
      else
        %{conn | params: Map.put(conn.params, :destination, destination)}
      end
    else
      Conn.resp(conn, 400, "Bad Request: Missing Destination header")
    end
  end

  defp if_set_send(conn) do
    case conn.state do
      :set -> Conn.halt(Conn.send_resp(conn))
      :sent -> Conn.halt(conn)
      _ -> conn
    end
  end

  defp handle_etag(conn) do
    resource = Map.get(conn.params, :resource)

    if resource do
      etag = Estore.Resource.get_etag(resource)

      if Plug.Conn.get_req_header(conn, "if-none-match") == etag do
        Conn.resp(conn, 304, "Not Modified")
      else
        Conn.put_resp_header(conn, "etag", etag)
      end
    else
      conn
    end
  end
end
