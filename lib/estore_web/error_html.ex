defmodule EstoreWeb.ErrorHTML do
  use EstoreWeb, :controller

  def render(_, %{status: status, stack: stack, reason: err}) do
    Sentry.capture_exception(err, stacktrace: stack)
    "Error"
  end
end
