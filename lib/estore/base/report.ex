defmodule Estore.Report do
  @callback report(resource :: Estore.Resource.t(), contents :: any(), depth :: Integer.t()) ::
              any()
  @callback root() :: {String.t(), String.t()}

  defmacro __using__(opts) do
    quote do
      @behaviour Estore.Report
      @before_compile Estore.Report
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def serves_report?(ns, name) do
        {ns, name} == root()
      end
    end
  end

  def get_supported_reports(resource) do
    [Estore.Report.ExpandProperties, Estore.Report.Multiget, Estore.Report.CalQuery]
  end
end
