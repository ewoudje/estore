defmodule EstoreWeb.ReportMethod do
  use EstoreWeb, :controller

  def report(conn, %{resource: resource, xml: xml}) do
    {{ns, name}, _, _} = xml

    case Enum.find(Estore.Report.get_supported_reports(resource), & &1.serves_report?(ns, name)) do
      nil ->
        Plug.Conn.send_resp(conn, 404, "")

      report ->
        EstoreWeb.DavController.multistatus(
          conn,
          report.report(resource, xml)
        )
    end
  end
end
