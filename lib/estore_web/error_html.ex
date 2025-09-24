defmodule EstoreWeb.ErrorHTML do
  use EstoreWeb, :controller

  def render(template, assigns) do
    IO.inspect(assigns)
    IO.inspect(template)
  end
end
