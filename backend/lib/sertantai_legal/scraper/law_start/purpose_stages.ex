defmodule SertantaiLegal.Scraper.LawStart.PurposeStages do
  @moduledoc """
  The stages of a whole law brought in by purpose in one statement: "…
  shall come into force, for the purpose of regulation 10(2), on 20th March
  1991 and for all other purposes on 1st September 1991" (SI 1991/346
  reg.1(1)). Partly in force is a provision's label (Jason 2026-11-20), and
  a purpose naming the law's own provisions is a list of them (Jason
  2026-11-21: "18(1) is full in force one month after made and everything
  else 5th October", SI 2015/776). So where the narrow purpose comes first,
  the provisions it names are fully in force on its day and every other
  provision on the last day; a narrow purpose naming no provision keeps the
  whole law partly in force until the last day. Where "all other purposes"
  comes first, only the provisions the waiting purpose names wait
  (`settle/2`). Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.Clause

  @stages ~r/^\W*(for\s+the\s+purposes?\s+(?:only\s+)?of\s+.+?)\s*,?\s+((?:on|from)\s+[^,;]+?\d{4})\s*[,;]?\s*(?:and|but)\s*,?\s+for\s+all\s+(?:other|remaining)\s+purposes\s*,?\s+((?:on|from)\s+.+?)\W*$/is

  @type stage :: {:partial, String.t(), Date.t()} | {:full, nil, Date.t()}

  @doc """
  The stages `tail` (what follows a statement's "into force") states:
  `{:partial, purpose, date}` then `{:full, nil, date}`; nil when it is no
  such statement, or a day is unread.
  """
  @spec read(String.t(), Date.t() | nil) :: [stage()] | nil
  def read(tail, made) do
    with [_, purpose, first, rest] <- Regex.run(@stages, tail),
         {_, %Date{} = partial} <- Clause.tail_date(first, made),
         {_, %Date{} = full} <- Clause.tail_date(rest, made) do
      [{:partial, purpose, partial}, {:full, nil, full}]
    else
      _ -> nil
    end
  end

  @doc """
  A list of whole-law stage groups settled by day, where "for all other
  purposes" comes first ("(a) for the purposes of regulation 4 as it gives
  effect to paragraphs 50(a) and 54(8) of Schedule 1, on 1st May 2007; and
  (b) for all other purposes, on 1st May 2004": SI 2004/1261 reg.1). Partly
  in force is a provision's label (Jason 2026-11-20): the provisions a
  waiting purpose names (`named`, a group's own provisions) are partly in
  force from the general day and fully from the purpose's; every other
  provision is fully in force from the general day. A waiting purpose that
  names no provision keeps the whole law partly in force until the last
  day. Any other groups are returned as given.
  """
  @spec settle([map()], (map() -> [term()])) :: [map()]
  def settle(groups, named) do
    with true <- Enum.all?(groups, &whole_law?/1),
         [full] <- Enum.filter(groups, &(&1.treatment == :provision_dated)) do
      groups
      |> Enum.map(&named_first(&1, full, named))
      |> waiting(full, named)
    else
      _ -> groups
    end
  end

  # a narrow purpose before the general day, naming the law's own
  # provisions: those provisions, fully in force on its day (SI 2015/776
  # art.1(c)(i) "for the purposes of article 18(1)"); naming none, the
  # whole law stays partly in force from it
  defp named_first(%{treatment: :provision_qualified} = g, full, named) do
    with :lt <- Date.compare(day(g), day(full)),
         [_ | _] = refs <- named.(g) do
      %{
        g
        | kind: :named,
          refs: refs,
          treatment: :provision_dated,
          date: day(g),
          qualified_date: nil
      }
    else
      _ -> g
    end
  end

  defp named_first(g, _full, _named), do: g

  defp waiting(groups, full, named) do
    case Enum.filter(groups, &(&1.kind == :remaining and Date.compare(day(&1), day(full)) == :gt)) do
      [] -> groups
      waiting -> waiting |> Enum.map(&{&1, named.(&1)}) |> settled(groups, full)
    end
  end

  # every waiting purpose names provisions: those wait, the rest is in
  # fully on the general day; else the whole law waits for its last day
  defp settled(waiting, groups, full) do
    if Enum.all?(waiting, fn {_g, refs} -> refs != [] end) do
      (groups -- Enum.map(waiting, &elem(&1, 0))) ++
        Enum.flat_map(waiting, fn {g, refs} -> named_stages(g, refs, day(full)) end)
    else
      last = Enum.max_by(groups, &day/1, Date)
      Enum.map(groups, &restage(&1, last))
    end
  end

  defp named_stages(g, refs, general) do
    named = %{g | kind: :named, refs: refs}

    [
      %{named | treatment: :provision_qualified, date: nil, qualified_date: general},
      %{named | treatment: :provision_dated, date: day(g), qualified_date: nil}
    ]
  end

  defp whole_law?(%{kind: :remaining, refs: [], excluded: []} = g),
    do: match?(%Date{}, day(g)) and not is_binary(Map.get(g, :territory))

  defp whole_law?(_group), do: false

  defp day(g), do: g.date || g.qualified_date

  # (a provision a narrow purpose named stays fully in force on its day)
  defp restage(%{kind: :named} = g, _last), do: g

  defp restage(g, last) when g == last,
    do: %{g | treatment: :provision_dated, date: day(g), qualified_date: nil}

  defp restage(g, _last),
    do: %{g | treatment: :provision_qualified, date: nil, qualified_date: day(g)}
end
