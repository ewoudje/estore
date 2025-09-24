defmodule EstoreWeb.DavController do
  use EstoreWeb, :controller

  def propfind(conn, %{
        xml: xml,
        resource: resource,
        depth: depth
      }) do
    :telemetry.span([:dav, :propfind], %{depth: depth}, fn ->
      {case EstoreWeb.Parsing.Propfind.xml(xml) do
         {:ok, properties} ->
           multistatus(
             conn,
             Estore.Propfind.get(resource, properties, depth)
           )

         {:error, error} ->
           Plug.Conn.send_resp(conn, 400, "Error: #{error}")
       end, %{}}
    end)
  end

  def proppatch(conn, %{
        xml: xml,
        resource: resource
      }) do
    case EstoreWeb.Parsing.Proppatch.xml(xml) do
      {:ok, setters, removal} ->
        multistatus(
          conn,
          [Estore.Proppatch.apply(resource, setters, removal)]
        )

      {:error, error} ->
        Plug.Conn.send_resp(conn, 400, "Error: #{error}")
    end
  end

  def mkcol(conn, %{parent: parent}) do
    container_ref = String.ends_with?(conn.request_path, "/")

    path =
      if conn.request_path != "/" and container_ref do
        String.slice(conn.request_path, 0..-2//1)
      else
        conn.request_path
      end

    true = String.starts_with?(path, parent.fqn)
    name = String.slice(path, String.length(parent.fqn)..-1//1)

    collection = Estore.Resource.create(parent, name, true)
    Estore.StdProperties.set(collection, name)
    Plug.Conn.send_resp(conn, 201, "Created")
  end

  def delete(conn, %{resource: resource}) do
    Estore.Repo.delete(resource)
    Plug.Conn.send_resp(conn, 204, "Deleted")
  end

  def copy(conn, %{resource: resource, destination: destination}) do
    parent = Estore.Resource.get_parent(destination)
    Estore.Resource.create(parent, destination, resource.collection)
    Estore.File.copy(resource, destination)
    # TODO copy properties, and copy depth
    Plug.Conn.send_resp(conn, 201, "Copied")
  end

  def move(conn, %{resource: resource, destination: destination}) do
    parent = Estore.Resource.get_parent(destination)
    Estore.Repo.update(Estore.Resource.changeset(resource, %{fqn: destination, parent: parent}))
    Plug.Conn.send_resp(conn, 204, "Moved")
  end

  def multistatus(conn, responses) do
    Sentry.Context.set_extra_context(%{multistatus_responses: responses})

    conn
    |> put_resp_content_type("application/xml")
    |> send_resp(207, Estore.XML.encode({:multistatus, responses}))
  end
end
