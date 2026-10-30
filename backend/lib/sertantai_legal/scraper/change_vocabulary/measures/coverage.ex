defmodule SertantaiLegal.Scraper.ChangeVocabulary.Measures.Coverage do
  @moduledoc """
  The coverage figures the step sessions published, each defined once
  (change vocabulary CV-S10). Before this they were worked out by hand
  from task output or scratch queries.

  All count **text changes**: merged changes whose chosen operation is
  inserted, substituted, repealed, repealed_in_part or renumbered.

  - `stated_by/1`, `stated_by_split/1` (CV-07): who states a change, from
    the claims of its operation only (`41f9afe0`). A gap the law's text
    fills on another attribute (an extent, a date) doesn't make it the
    law's. `:law_and_derived` is the register's `stated_by_law_and_derived`,
    not "joined" (any two sources, `MergeStrata` J).
  - `law_text_coverage/2` (CV-S06): the derived-only changes placed by the
    conflict report's entry for each: the amending provision read with no
    rule (by target: Schedule, EU article, body), not read, or other
    (beside an unjoined law-text change, or the amending law not indexed).
  - `dating/1` (CV-S08): what dates a change.
  - `territory_groups/1` (CV-S05): the extent check's "territory from"
    outcomes grouped.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence}

  @text ~w(inserted substituted repealed repealed_in_part renumbered)a

  @doc "Whether a change is a text change (by its chosen operation)."
  @spec text?(Change.t()) :: boolean()
  def text?(%Change{resolved: %{operation: op}}), do: op in @text
  def text?(_change), do: false

  @doc "Who states the change: the tiers of the sources claiming its operation."
  @spec stated_by(Change.t()) :: :law_and_derived | :law_only | :derived_only | :none
  def stated_by(%Change{claims: claims}) do
    tiers =
      for c <- claims, c.attribute == :operation, into: MapSet.new(), do: Evidence.tier(c.source)

    case {:primary in tiers, :derived in tiers} do
      {true, true} -> :law_and_derived
      {true, false} -> :law_only
      {false, true} -> :derived_only
      {false, false} -> :none
    end
  end

  @doc "Text changes counted by `stated_by/1`."
  @spec stated_by_split([Change.t()]) :: %{atom() => non_neg_integer()}
  def stated_by_split(changes) do
    text = Enum.filter(changes, &text?/1)
    counts = Enum.frequencies_by(text, &stated_by/1)

    %{
      total: length(text),
      law_and_derived: Map.get(counts, :law_and_derived, 0),
      law_only: Map.get(counts, :law_only, 0),
      derived_only: Map.get(counts, :derived_only, 0),
      none: Map.get(counts, :none, 0)
    }
  end

  @doc """
  CV-S06's coverage table: text changes by who states them, the
  derived-only ones placed by their entry in `conflicts`
  (`Conflicts.report/2` over the same changes, with the read pass's
  pointers).
  """
  @spec law_text_coverage([Change.t()], [map()]) :: %{atom() => non_neg_integer()}
  def law_text_coverage(changes, conflicts) do
    entry =
      for %{kind: k} = e <- conflicts, k in [:uncovered, :unread], into: %{} do
        {{e.key, e.target}, e}
      end

    text = Enum.filter(changes, &text?/1)

    zero = %{
      law_and_derived: 0,
      law_only: 0,
      read_no_rule_schedule: 0,
      read_no_rule_eu_article: 0,
      read_no_rule_body: 0,
      not_read: 0,
      other: 0
    }

    text
    |> Enum.map(fn c ->
      case stated_by(c) do
        :law_and_derived -> :law_and_derived
        :law_only -> :law_only
        _ -> derived_place(c, entry[{c.key, c.target}])
      end
    end)
    |> Enum.reduce(zero, fn k, acc -> Map.update!(acc, k, &(&1 + 1)) end)
    |> Map.put(:total, length(text))
  end

  defp derived_place(c, %{kind: :uncovered, missing: :primary}) do
    cond do
      String.starts_with?(c.target, "sch.") -> :read_no_rule_schedule
      String.starts_with?(c.target, "art.") -> :read_no_rule_eu_article
      true -> :read_no_rule_body
    end
  end

  defp derived_place(_c, %{kind: :unread}), do: :not_read
  defp derived_place(_c, _entry), do: :other

  @doc "CV-S08's dating coverage: text changes by what dates them."
  @spec dating([Change.t()]) :: %{atom() => non_neg_integer()}
  def dating(changes) do
    text = Enum.filter(changes, &text?/1)

    counts =
      Enum.frequencies_by(text, fn
        %{resolved: %{date: nil}} -> :undated
        %{resolved: %{commenced_by: nil}} -> :dated_no_commenced_by
        _ -> :commenced_by_named
      end)

    %{
      total: length(text),
      undated: Map.get(counts, :undated, 0),
      dated_no_commenced_by: Map.get(counts, :dated_no_commenced_by, 0),
      commenced_by_named: Map.get(counts, :commenced_by_named, 0)
    }
  end

  @groups %{
    "bound:law" => :law_text,
    "territory:law" => :law_text,
    "none:same" => :follows_enactment,
    "none:same_or_not_named" => :follows_enactment,
    "territory:feed" => :feed_or_markup,
    "territory:markup" => :feed_or_markup,
    "none:law_type_not_read" => :law_type_not_read,
    "none:law_no_powers" => :no_powers,
    "none:unread_statement" => :unread_statement,
    "none:competence_only" => :competence_only,
    "none:no_amending_law" => :no_amending_law
  }

  @doc """
  CV-S05's table: the extent check's "territory from" outcome counts
  grouped (`bound:law` and `territory:law` are the law's text; `same` and
  `same_or_not_named` follow the enactment; any other `none:` is other).
  """
  @spec territory_groups(%{String.t() => non_neg_integer()}) :: %{atom() => non_neg_integer()}
  def territory_groups(counts) do
    zero = @groups |> Map.values() |> Map.new(&{&1, 0}) |> Map.put(:other, 0)

    counts
    |> Enum.reduce(zero, fn {outcome, n}, acc ->
      Map.update!(acc, Map.get(@groups, outcome, :other), &(&1 + n))
    end)
    |> Map.put(:total, counts |> Map.values() |> Enum.sum())
  end
end
