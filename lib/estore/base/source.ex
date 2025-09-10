defmodule Estore.Source do
  use Ecto.Schema
  import Ecto.Changeset

  @callback new(resource :: Estore.Resource.t()) :: :ok
  @callback read(data :: any, resource :: Estore.Resource.t()) ::
              {:ok, binary()} | :unsupported | :not_found
  @callback write(
              data :: any,
              resource :: Estore.Resource.t(),
              write :: binary(),
              state :: any
            ) :: {:ok, any} | :no_source | :unsupported
  @callback finish_write(
              data :: any,
              resource :: Estore.Resource.t(),
              state :: any
            ) :: :ok | {:error, any}
  @callback extensions(data :: any) :: [atom()]

  schema "sources" do
    field(:type, :string)
    field(:data, :map)
  end

  def changeset(source, attrs) do
    source
    |> cast(attrs, [:type, :data])
    |> validate_required([:type])
  end

  def new(module) do
    type = Atom.to_string(module.__info__(:module))
    Estore.Repo.insert(%Estore.Source{type: type, data: %{}})
  end

  def get(module) do
    type = Atom.to_string(module.__info__(:module))
    Estore.Repo.get_by(Estore.Source, type: type)
  end

  def init(resource) do
    case get_source(resource) do
      {module, data} ->
        module.new(data, resource)

      nil ->
        :no_source
    end

    resource
  end

  def write(resource, write, state \\ nil) do
    case get_source(resource) do
      {module, data} ->
        module.write(data, resource, write, state)

      nil ->
        :no_source
    end
  end

  def finish_write(resource, state) do
    case get_source(resource) do
      {module, data} ->
        module.finish_write(data, resource, state)

      nil ->
        :no_source
    end
  end

  def read(resource) do
    case get_source(resource) do
      {module, data} ->
        module.read(data, resource)

      nil ->
        :no_source
    end
  end

  def add_extensions(source, extensions) do
    case source do
      nil ->
        extensions

      %Estore.Source{type: type, data: data} ->
        String.to_existing_atom(type).extensions(data) ++ extensions
    end
  end

  defp get_source(resource) do
    case Estore.Repo.preload(resource, :source) do
      %Estore.Resource{source: nil} ->
        nil

      %Estore.Resource{source: %Estore.Source{type: type, data: data}} ->
        {String.to_existing_atom(type), data}
    end
  end

  defmacro __using__(opts) do
    quote do
      use Estore.Extension
      @behaviour Estore.Source
      @before_compile Estore.Source
    end
  end

  defmacro __before_compile__(_) do
    quote do
      @impl Estore.Source
      def extensions(_), do: [__MODULE__]

      @impl Estore.Extension
      def serves_property?("https://ewoudje.com/ns", "source"), do: true

      def properties(_, _, {"https://ewoudje.com/ns", "source"}) do
        {:value, __MODULE__}
      end

      def source() do
        Estore.Source.get(__MODULE__)
      end
    end
  end
end
