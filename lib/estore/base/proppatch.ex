defmodule Estore.Proppatch do
  def apply(resource, set, remove) do
    {:response, resource,
     do_properties(
       resource,
       Estore.Extension.apply_for_properties(:prep_set, resource, set),
       Estore.Extension.apply_for_properties(:prep_remove, resource, remove)
     )}
  end

  defp do_properties(resource, set, remove) do
    errors = Enum.filter(set, &is_error/1) ++ Enum.filter(remove, &is_error/1)

    if errors == [] do
      for {_, prep, {fetched, extension}} <- set do
        :ok = extension.apply_prep(resource, fetched, {:set, prep})
      end

      [{:propstat, :ok, Enum.map(set ++ remove, &elem(&1, 0))}]
    else
      alright =
        (Enum.filter(set, &(!is_error(&1))) ++ Enum.filter(remove, &(!is_error(&1))))
        |> Enum.map(&elem(&1, 0))

      errors =
        errors
        |> Enum.chunk_by(&elem(&1, 1))
        |> Enum.map(fn [{_, error, _} | _] = errs ->
          {:propstat, error, Enum.map(errs, &elem(elem(&1, 0), 0))}
        end)

      if alright == [] do
        errors
      else
        [
          {:propstat, :failed_dependency, alright}
          | errors
        ]
      end
    end
  end

  defp is_error({_, :not_found, _}), do: true
  defp is_error({_, :not_allowed, _}), do: true
  defp is_error({_, :bad_input, _}), do: true
  defp is_error(_), do: false
end
