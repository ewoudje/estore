defmodule EstoreWeb.SourceMethods do
  use EstoreWeb, :controller

  def get(conn, %{resource: resource}) do
    case Estore.Source.read(resource) do
      {:ok, data} ->
        Plug.Conn.send_resp(conn, 200, data)

      :no_source ->
        Plug.Conn.send_resp(conn, 403, "")

      :not_found ->
        Plug.Conn.send_resp(conn, 404, "")

      :unsupported ->
        Plug.Conn.send_resp(conn, 403, "")
    end
  end

  def put(conn, %{resource: _, parent: nil}),
    do: Plug.Conn.send_resp(conn, 401, "Can't put to root")

  def put(conn, %{resource: resource, parent: parent, user: user}) do
    name = String.split(conn.request_path, "/") |> List.last()
    parent = Estore.Repo.preload(parent, [:source])

    source =
      if parent.source do
        Estore.Source.child_source(parent.source)
      else
        Estore.File.source()
      end

    {resource, created} =
      cond do
        Estore.Source.parent_put?(source) ->
          {parent, false}

        resource == nil ->
          {Estore.Resource.create(parent, name, false,
             source: source,
             owner_id: user.principal_id
           ), true}

        true ->
          {resource, false}
      end

    {conn, :ok} = write_body(conn, resource)

    {"content-type", _content_type} =
      List.keyfind(
        conn.req_headers,
        "content-type",
        0,
        {"content-type", "application/octet-stream"}
      )

    # Updates timestamps
    Estore.StdProperties.set(resource, name)

    Plug.Conn.send_resp(
      conn,
      if(created, do: 201, else: 200),
      if(created, do: "Created", else: "Modified")
    )
  end

  defp write_body(conn, resource, state \\ nil) do
    case Plug.Conn.read_body(conn) do
      {:ok, content, conn} ->
        {:ok, state} = Estore.Source.write(resource, content, state)
        {conn, Estore.Source.finish_write(resource, state)}

      {:more, content, conn} ->
        {:ok, state} = Estore.Source.write(resource, content, state)
        write_body(conn, resource, state)

      {:error, error} ->
        {Plug.Conn.send_resp(conn, 500, "Error: #{error}"), 0}
    end
  end
end
