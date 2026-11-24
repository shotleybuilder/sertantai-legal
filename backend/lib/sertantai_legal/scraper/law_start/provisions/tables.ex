defmodule SertantaiLegal.Scraper.LawStart.Provisions.Tables do
  @moduledoc """
  A commencement table's rows (provision, date, purpose) as groups. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.ScheduleTable
  alias SertantaiLegal.Scraper.LawStart.Provisions.{Refs, Words}

  @doc """
  The groups of a clause commencing by its Schedule's table (V1-02,
  `LawStart.ScheduleTable`): one per table row, its provisions dated in
  full when its purpose is all ("All purposes", "In respect of all
  buildings") and the provision carries no qualifier of its own ("Regulation
  17 (for the purpose of new regulation 25A)"); else partial.
  """
  @spec table_groups([map()], LawStart.t(), map() | nil) :: [map()]
  def table_groups(rows, %LawStart{evidence: evidence, text: text}, tables)
      when is_binary(evidence) and is_map(tables) do
    base = Words.provision(evidence)

    for %{date: date, provisions: p, purpose: purpose} <- ScheduleTable.rows(text, tables),
        {qualified, refs} = cell_refs(p, rows, base),
        g <- [
          table_group(refs -- qualified, all_purposes?(purpose), date, evidence, p, purpose),
          table_group(qualified, false, date, evidence, p, purpose)
        ],
        g != nil,
        do: g
  end

  def table_groups(_rows, _law, _tables), do: []

  defp all_purposes?(purpose), do: purpose == nil or purpose =~ ~r/\ball\b/i

  defp table_group([], _full?, _date, _evidence, _p, _purpose), do: nil

  defp table_group(refs, full?, date, evidence, p, purpose),
    do: %{
      kind: :named,
      refs: refs,
      excluded: [],
      treatment: if(full?, do: :provision_dated, else: :provision_qualified),
      date: if(full?, do: date, else: nil),
      qualified_date: if(full?, do: nil, else: date),
      evidence: evidence,
      text: Enum.join(Enum.reject([p, purpose], &is_nil/1), " | ")
    }

  # a cell's refs, and those an item qualifies in brackets of its own:
  # "Regulations 1-10, 11(a) (in so far as it inserts …) and (b), 12" — only
  # 11(a) is partial; items split at commas and "and" outside brackets, a
  # bare number taking the cell's provision noun
  defp cell_refs(p, rows, base) do
    noun =
      case Regex.run(~r/^\s*(regulations?|sections?|articles?|rules?)\b/i, p) do
        [_, n] -> n
        nil -> ""
      end

    qualified =
      p
      |> split_items()
      |> Enum.filter(&qualified_provision?/1)
      |> Enum.flat_map(fn item ->
        item = strip_qualifier(item)
        item = if item =~ ~r/^\s*\d/, do: noun <> " " <> item, else: item
        Refs.refs(item, rows, base)
      end)

    {qualified, Refs.refs(strip_qualifier(p), rows, base)}
  end

  defp split_items(p) do
    {items, cur, _depth} =
      p
      |> String.graphemes()
      |> Enum.reduce({[], "", 0}, fn
        "(", {items, cur, d} -> {items, cur <> "(", d + 1}
        ")", {items, cur, d} -> {items, cur <> ")", max(d - 1, 0)}
        ",", {items, cur, 0} -> {[cur | items], "", 0}
        c, {items, cur, d} -> {items, cur <> c, d}
      end)

    [cur | items]
    |> Enum.reverse()
    |> Enum.flat_map(&String.split(&1, ~r/\s+and\s+(?![^()]*\))/))
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
  end

  # a provision's own qualifier in brackets ("(for the purpose of new
  # regulation 25A)", "(in so far as it inserts …)"); "(so far as not
  # otherwise commenced)" completes it
  defp qualified_provision?(p),
    do:
      p =~ ~r/\((?:for the purposes? of|in so far as|so far as|insofar as)\b/i and
        not (p =~ ~r/\(\s*(?:in )?so far as not (?:otherwise|already)\b/i)

  # bracketed asides with words in them are qualifiers, not numbers ("and
  # (b)" stays)
  # ("13(a) (in so far as it inserts paragraphs (3B) … into regulation 20) and (b)")
  defp strip_qualifier(p),
    do: Regex.replace(~r/\s\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/, p, "")
end
