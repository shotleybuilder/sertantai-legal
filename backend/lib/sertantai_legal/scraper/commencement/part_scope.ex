defmodule SertantaiLegal.Scraper.Commencement.PartScope do
  @moduledoc """
  A rule's Part and Chapter refs written out as the provisions they hold,
  for an amending law we hold no LAT rows for: the build evaluates its
  stored rules with no row context, so "pt.7" would reach no section
  (Planning (Wales) Act 2015 s.58(2)(b): "Parts 3 to 8, so far as is
  necessary for enabling …" never reached s.47). The Parts come from the
  law's own document when its rules are written (`OwnClause.doc_rows/1`,
  whose rows carry their containers), as `ScheduleEffect` writes out a
  Schedule's Part. Exceptions are written out the same way. A Schedule's
  Part, and a Part the document doesn't hold, stay as read. Pure.
  """

  alias SertantaiLegal.Scraper.Commencement.Rule

  @part ~r/^pt\.([^.]+)(?:\.ch\.([^.]+))?$/

  @doc "`rules` with each body Part or Chapter in a scope or exception replaced by its provisions in `rows`."
  @spec expand([Rule.t()], [map()]) :: [Rule.t()]
  def expand(rules, rows) do
    case held(rows) do
      held when map_size(held) == 0 -> rules
      held -> Enum.map(rules, &rule(&1, held))
    end
  end

  defp rule(%Rule{scope: scope, except: except} = rule, held) when is_list(scope),
    do: %Rule{rule | scope: refs(scope, held), except: refs(except, held)}

  defp rule(%Rule{except: except} = rule, held), do: %Rule{rule | except: refs(except, held)}

  defp refs(refs, held), do: refs |> Enum.flat_map(&provisions(&1, held)) |> Enum.uniq()

  defp provisions(ref, held) do
    case Regex.run(@part, ref) do
      [_, part] -> Map.get(held, {part, nil}, [ref])
      [_, part, chapter] -> Map.get(held, {part, chapter}, [ref])
      nil -> [ref]
    end
  end

  # each Part's, and each Part's Chapter's, top-level provisions in
  # document order
  defp held(rows) do
    rows
    |> Enum.flat_map(&containers/1)
    |> Enum.uniq()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp containers(%{section_id: id} = row) do
    case {Map.get(row, :part), Map.get(row, :chapter)} do
      {nil, _} -> []
      {part, nil} -> [{{part, nil}, top(id)}]
      {part, chapter} -> [{{part, nil}, top(id)}, {{part, chapter}, top(id)}]
    end
  end

  defp top(id), do: id |> String.split(":") |> List.last() |> String.replace(~r/\(.*$/, "")
end
