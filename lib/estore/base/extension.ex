defmodule Estore.Extension do
  @extensions [
    Estore.StdExtension,
    Estore.DeadExtension,
    Estore.PermsExtension
  ]

  def apply_for_properties(action, resource, properties) do
    :telemetry.span([:dav, :afprops], %{action: action}, fn ->
      {Enum.flat_map(Estore.Resource.add_source_extensions(resource, @extensions), fn extension ->
         if Enum.any?(properties, fn
              {namespace, name} ->
                extension.serves_property?(namespace, name)

              {{namespace, name}, _, _} ->
                extension.serves_property?(namespace, name)
            end) do
           case extension.fetch(resource) do
             {:ok, fetched} ->
               Enum.map(
                 properties,
                 &{&1, apply(extension, action, [resource, fetched, &1]), {fetched, extension}}
               )

             :not_found ->
               [:not_found]
           end
         else
           []
         end
       end), %{}}
    end)
  end

  @type prep_error() :: :not_allowed | :not_found | :bad_input
  @type property() :: {String.t(), String.t()}

  @callback serves_property?(namespace :: String.t(), name :: String.t()) :: boolean
  @callback fetch(resource :: Estore.Resource) :: {:ok, any} | :not_found | {:error, any}
  @callback properties(resource :: Estore.Resource, fetched :: any, requested :: property()) ::
              any | :not_found

  @callback prep_remove(resource :: Estore.Resource, fetched :: any, remove :: property()) ::
              prep_error() | any

  @callback prep_set(resource :: Estore.Resource, fetched :: any, set :: {property(), any}) ::
              prep_error() | any

  @callback apply_prep(
              resource :: Estore.Resource,
              fetched :: any,
              prep :: {:set, any} | {:remove, any}
            ) ::
              :ok | {:error, any}

  defmacro __using__(opts) do
    quote do
      @behaviour Estore.Extension
      @before_compile Estore.Extension
    end
  end

  defmacro __before_compile__(_) do
    quote do
      @impl true
      def serves_property?(_, _), do: false

      @impl true
      def properties(_, _, _), do: :not_found

      @impl true
      def fetch(_), do: :not_found

      @impl true
      def prep_remove(_, _, _), do: :not_found

      @impl true
      def prep_set(_, _, _), do: :not_found

      @impl true
      def apply_prep(_, _, _), do: {:error, :not_implemented}
    end
  end
end

defmodule Estore.StdExtension do
  use Estore.Extension

  @impl true
  def fetch(resource) do
    {:ok, Estore.StdProperties.of(resource)}
  end

  @impl true
  def serves_property?("DAV:", name) do
    name in [
      "resourcetype",
      "getlastmodified",
      "displayname",
      "getetag",
      "supported-report-set",
      "current-user-privilege-set",
      "current-user-principal",
      "owner"
    ]
  end

  @impl true
  def serves_property?("https://ewoudje.com/ns", name) do
    name in [
      "uuid",
      "parent"
    ]
  end

  @impl true
  def properties(resource, stdprops, requested) do
    case requested do
      {"DAV:", "getetag"} ->
        {:value, Estore.Resource.get_etag(resource)}

      {"DAV:", "resourcetype"} ->
        # Allow other extensions to add thier own types
        if resource.collection do
          {:append, {{"DAV:", "collection"}, [], []}}
        else
          {:empty}
        end

      {"DAV:", "getlastmodified"} ->
        {:value, stdprops.updated_at}

      {"DAV:", "displayname"} ->
        {:value, stdprops.display_name}

      {"DAV:", "supported-report-set"} ->
        {:value, Enum.map(Estore.Report.get_supported_reports(resource), &{&1.root(), [], []})}

      {"DAV:", "owner"} ->
        {:value, {:href, Estore.Repo.preload(resource, [:owner]).owner}}

      {"https://ewoudje.com/ns", "uuid"} ->
        {:value, resource.id}

      {"https://ewoudje.com/ns", "parent"} ->
        {:value, resource.parent_id}

      _ ->
        :not_found
    end
  end

  @impl true
  def prep_set(resource, stdprops, set) do
    case set do
      {{"DAV:", "displayname"}, [], [value]} ->
        if is_bitstring(value) do
          {:display_name, value}
        else
          :bad_input
        end

      {{ns, name}, [], value} ->
        if serves_property?(ns, name) do
          :not_allowed
        else
          :not_found
        end

      _ ->
        :explode
    end
  end

  @impl true
  def prep_remove(_, _, _), do: :not_allowed

  @impl true
  def apply_prep(_, stdprops, {:set, prep}) do
    Estore.Repo.update!(Estore.StdProperties.changeset(stdprops, Map.new([prep])))
    :ok
  end
end
