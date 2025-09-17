defmodule EstoreWeb.RecieveMailController do
  use EstoreWeb, :controller

  def render(conn, input) do
    IO.inspect(conn)
    IO.inspect(input)
  end
end
