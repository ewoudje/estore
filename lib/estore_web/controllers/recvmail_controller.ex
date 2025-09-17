defmodule EstoreWeb.RecieveMailController do
  use EstoreWeb, :controller

  def post(conn, input) do
    IO.inspect(conn)
    IO.inspect(input)
  end
end
