defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Check do
  @moduledoc """
  The extent and application reader's check, pure (`mix lat.extent_check`
  reads the DB and the read cache, and prints). It gives:

  - **amending laws:** each law's extent basis as the reader reads it now
    (`clause`, `lists`, `application`, `powers`, `competence`, or `none`
    with why), our fault where the stored `extent_rules` differ from the
    reading (`stale`) or none are stored (`not_stored`), the law's own
    extent sentences left unread, and those the catalogue misses;
  - **text changes:** where each stored text change's territory comes from,
    or why none;
  - the tallies the task prints, and the items a sample file holds.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Extent, SweepForm}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Lookup, Store, Unread}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Coverage

  # ── amending laws ────────────────────────────────────────────────────

  @doc "A law whose type the reader doesn't read, or whose text isn't held."
  @spec unread_law(String.t(), String.t()) :: map()
  def unread_law(law, why),
    do: %{
      law: law,
      basis: "none",
      why: why,
      fault: nil,
      unread: %{},
      withholding: [],
      uncaught: [],
      words: nil
    }

  @doc """
  A law's row from its cached reading (`ReadCache.law/1`), its extent with
  enabling powers added (`Extent.Powers.with_powers/3`) and its stored
  `extent_rules` rows (nil when none are stored).
  """
  @spec law_row(String.t(), map(), Extent.t(), [map()] | nil) :: map()
  def law_row(law, reading, %Extent{} = e, stored) do
    classes = reading.classes
    {basis, why} = basis(e, law)

    unread =
      classes
      # (every unread class, list_partial and provision_* too)
      |> Enum.filter(fn {_, _, c} -> String.starts_with?(c, "unread:") end)
      |> Enum.frequencies_by(&elem(&1, 2))

    fault =
      cond do
        stored == nil -> "not_stored"
        MapSet.new(stored) != rows(e, law) -> "stale"
        true -> nil
      end

    %{
      law: law,
      basis: basis,
      why: why,
      fault: fault,
      unread: unread,
      # the statements that withhold a bound (`Extent.Unread`), for the gate
      withholding:
        for(
          {ref, s, c} <- classes,
          c in Unread.classes(),
          do: "#{ref}: #{String.slice(s, 0, 200)} (#{c})"
        ),
      # the sweep's sentences the catalogue misses, with their form
      uncaught: for({ref, s, _net} <- reading.uncaught, do: {ref, s, SweepForm.form(s)}),
      extent: e,
      words: e.text || words(classes)
    }
  end

  @doc "Where a law's extent comes from, and why none."
  @spec basis(Extent.t(), String.t()) :: {String.t(), String.t() | nil}
  def basis(%Extent{} = e, law) do
    cond do
      e.default -> {"clause", nil}
      e.lists != [] -> {"lists", nil}
      e.application -> {"application", nil}
      e.powers -> {"powers", nil}
      e.stated -> {"stated", nil}
      e.competence -> {"competence", nil}
      act?(law) -> {"none", "no_clause"}
      true -> {"none", "no_powers"}
    end
  end

  @doc "A law row's basis as the report keys it."
  @spec key(map()) :: String.t()
  def key(%{basis: "none", why: why}), do: "none: #{why}"
  def key(%{basis: b}), do: b

  # the reading as the rows `mix lat.amending --extents` writes, as a set
  # (compared with the rows stored, never through `from_rows/1`)
  defp rows(%Extent{} = e, law),
    do:
      e
      |> Extent.to_rows(law)
      |> Enum.map(&Map.take(&1, Store.compared()))
      |> MapSet.new()

  # the law's first extent or application words, where it states none read
  defp words(classes) do
    Enum.find_value(classes, fn {ref, s, _} -> "#{ref}: #{s}" end)
  end

  defp act?(law), do: (String.split(law, "_") |> Enum.at(1)) in ~w(ukpga asp anaw asc nia apni)

  # ── text changes ─────────────────────────────────────────────────────

  @doc """
  A text change (with its territory and extent claims as `source:attribute=value`
  strings, and its amending provisions) with where its territory comes from,
  or `none:` and why from its amending law's row.
  """
  @spec change_row(map(), %{String.t() => map()}) :: map()
  def change_row(c, by_law) do
    has = fn prefix -> Enum.find(c.claims, &String.starts_with?(&1, prefix)) end

    outcome =
      cond do
        has.("law_text:territory=") -> "territory:law"
        has.("law_text:extent=") -> "bound:law"
        has.("feed:territory=") -> "territory:feed"
        has.("markup:territory=") -> "territory:markup"
        c.by == nil -> "none:no_amending_law"
        true -> "none:" <> none_why(Map.get(by_law, c.by), c.affecting)
      end

    Map.put(c, :outcome, outcome)
  end

  defp none_why(nil, _), do: "no_amending_law"
  defp none_why(%{basis: "none", why: why}, _), do: "law_" <> why
  defp none_why(%{basis: "competence"}, _), do: "competence_only"

  # the change's own amending provisions first: one following the
  # enactment it changes is `same`, whatever else the law leaves unread
  # (CPA 1987 Sch.3); a statement of the law's left unread withholds its
  # provisions' bound, never the default
  defp none_why(%{extent: %Extent{} = e} = row, affecting) do
    cond do
      affecting != [] and Lookup.of_change(e, affecting) == :same -> "same"
      affecting == [] and all_same?(e) -> "same"
      withheld?(e, affecting) -> "unread_statement"
      no_powers?(e, row) -> "law_no_powers"
      true -> none_listed(row)
    end
  end

  defp none_why(_, _), do: "unknown"

  # an unread statement withholds the change's bound only where the
  # reading without it would bound the change (a statement on another
  # provision leaves the law's own cause: SI 2009/1941 sch.1 para.84,
  # 2026-11-05); with no amending provision known, any may
  defp withheld?(%Extent{lists: lists} = e, affecting) do
    unread? = Enum.any?(lists, &match?({:unread, _, _}, &1))

    cond do
      not unread? ->
        false

      affecting == [] ->
        true

      true ->
        is_binary(
          Lookup.of_change(
            %{e | lists: Enum.reject(lists, &match?({:unread, _, _}, &1))},
            affecting
          )
        )
    end
  end

  # every amendment the law makes follows its enactment, and nothing else
  # is stated: any change of it does, its amending provision unknown (WSI
  # 2013/755 art.1)
  defp all_same?(%Extent{default: nil, lists: [_ | _] = lists}),
    do: Enum.all?(lists, &match?({:same, _, ["*"]}, &1))

  defp all_same?(_e), do: false

  # an SI stating no default and no powers read, its lists naming others
  defp no_powers?(%Extent{default: nil, powers: nil, stated: nil, competence: nil}, %{law: law}),
    do: not act?(law)

  defp no_powers?(_e, _row), do: false

  # (a same list first: a provision following the enactment it changes is
  # no provision left unnamed)
  defp none_listed(%{extent: %Extent{lists: lists, default: d}}) do
    cond do
      Enum.any?(lists, &match?({:same, _, _}, &1)) -> "same_or_not_named"
      d == nil and lists != [] -> "not_named"
      true -> "provision_not_named"
    end
  end

  # ── tallies ──────────────────────────────────────────────────────────

  @doc """
  The tallies the report prints: bases, our faults, unread classes, the
  sweep's misses, the text changes' outcomes and their grouping
  (`Measures.Coverage.territory_groups/1`).
  """
  @spec tallies([map()], [map()]) :: map()
  def tallies(rows, change_rows) do
    faults = Enum.filter(rows, & &1.fault)
    uncaught = for r <- rows, {ref, s, form} <- r.uncaught, do: {r.law, ref, s, form}
    outcomes = Enum.frequencies_by(change_rows, & &1.outcome)

    %{
      bases: rows |> Enum.frequencies_by(&key/1) |> Enum.sort_by(&(-elem(&1, 1))),
      faults: faults,
      fault_kinds: Enum.frequencies_by(faults, & &1.fault),
      unread:
        rows
        |> Enum.reduce(%{}, fn r, acc -> Map.merge(acc, r.unread, fn _, a, b -> a + b end) end)
        |> Enum.sort_by(&(-elem(&1, 1))),
      with_unread: Enum.count(rows, &(&1.unread != %{})),
      uncaught: uncaught,
      uncaught_laws: uncaught |> Enum.map(&elem(&1, 0)) |> Enum.uniq() |> length(),
      uncaught_forms:
        uncaught |> Enum.frequencies_by(&elem(&1, 3)) |> Enum.sort_by(&(-elem(&1, 1))),
      misses: Enum.filter(uncaught, fn {_, _, _, form} -> SweepForm.read?(form) end),
      outcomes: Enum.sort_by(outcomes, &(-elem(&1, 1))),
      groups: Coverage.territory_groups(outcomes)
    }
  end

  @doc "The order the grouped table prints its groups in."
  @spec groups() :: [atom()]
  def groups, do: Coverage.territory_group_names()

  # ── sample items ─────────────────────────────────────────────────────

  @doc "A sampled amending law, with the words behind its basis."
  @spec law_item(map()) :: map()
  def law_item(r) do
    %{
      "law" => r.law,
      "basis" => key(r),
      "default" => r[:extent] && r.extent.default,
      "application" => r[:extent] && r.extent.application,
      "powers" => r[:extent] && r.extent.powers,
      "competence" => r[:extent] && r.extent.competence,
      "lists" =>
        for(
          {k, p, items} <- (r[:extent] && r.extent.lists) || [],
          do: %{"kind" => to_string(k), "place" => p, "items" => Enum.take(items, 20)}
        ),
      "clause" => r.words,
      "unread" => r.unread
    }
  end

  @doc "A sampled text change (its effect id cut to the last six characters)."
  @spec change_item(map()) :: map()
  def change_item(c) do
    %{
      "law" => c.law,
      "target" => c.target,
      "operation" => c.operation,
      "by" => c.by,
      "territory" => c.territory,
      "outcome" => c.outcome,
      "claims" => c.claims,
      "key_tail" => String.slice(c.key || "", -6, 6)
    }
  end
end
