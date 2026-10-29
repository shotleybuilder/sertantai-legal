defmodule SertantaiLegal.Scraper.ChangeVocabulary.Conflicts do
  @moduledoc """
  Where the law's text and legislation.gov.uk disagree (source authority,
  Jason 2026-10-21: "primary wins, conflicts reported"). Derived from the
  merged changes, never stored (CV-04), so the rules can change without a
  rebuild. Three kinds (`report/1`):

  - `:value` — inside one change, a primary value and a derived claim on
    the same attribute that differ (`values/1`). Like for like only: the
    markup shows a substitution as an insertion (`@agree`), the law
    commencing a change is not the law making it (`commenced_by` apart),
    and words the law's text changes in a provision are a whole provision
    where the change sits below it (`:placed`).
  - `:unjoined` — a change only the law's text states beside a change only
    legislation.gov.uk states, by the same law, on the same provision or
    one above or below it: likely one event the merge left as two (both
    fold into the label).
  - `:uncovered` — a text change only legislation.gov.uk states although
    the amending provision it names was read (`missing: :primary`: the
    reader found no rule there), or only the law's text states with no
    record from legislation.gov.uk (`missing: :derived`). Commencements
    are not counted: a law's own commencement of each provision is the
    law's alone.
  - `:unread` — a text change only legislation.gov.uk states whose
    amending provision was not read (the read pass reads what our notes
    point to): coverage, not disagreement.

  Value conflicts compare the law's text with legislation.gov.uk's markup
  and feed only — not with our own inference of an affecting law's
  territory (`:law`).

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence}
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LatRef

  @type value_conflict :: {atom(), {atom(), term()}, {atom(), term()}}

  # a primary value and a derived one that say the same thing
  @agree [{:operation, :substituted, :inserted}]

  @text ~w(inserted substituted repealed repealed_in_part renumbered)a

  # the derived sources that are legislation.gov.uk's
  @legislation_gov_uk [:markup, :feed]

  @doc "The change's primary values each derived claim on the same attribute contradicts."
  @spec values(Change.t()) :: [value_conflict()]
  def values(%Change{resolved: nil}), do: []

  def values(%Change{resolved: r} = c) do
    derived = for {s, :derived} <- Evidence.tiers(), s in @legislation_gov_uk, do: s

    for {attribute, source} <- Enum.sort(r.sources),
        Evidence.tier(source) == :primary,
        value = Map.get(r, attribute),
        s <- derived,
        other <- Change.values(c, s, attribute),
        other != value,
        {attribute, value, other} not in @agree,
        not placed_above?(c, attribute, value, other),
        do: {attribute, {source, value}, {s, other}}
  end

  # the law's text named a provision above where the change sits: its
  # words there are a whole provision here
  defp placed_above?(c, :level, :words, :provision) do
    case Change.value(c, :law_text, :placed) do
      nil -> false
      placed -> placed in tl(LatRef.ancestors(c.target))
    end
  end

  defp placed_above?(_c, _attribute, _value, _other), do: false

  @doc """
  Every conflict in a law's changes, as maps with `kind`, `target`, `key`,
  `by` and the kind's detail.
  """
  @spec report([Change.t()], %{String.t() => [String.t()]} | nil) :: [map()]
  def report(changes, pointers \\ nil) do
    primary = Enum.filter(changes, &(tiers(&1) == [:primary] and text?(&1)))
    derived = Enum.filter(changes, &(tiers(&1) == [:derived] and text?(&1)))

    # the amending provisions whose text was read: the read pass's own
    # record (`pointers`: law → refs read, `Amendment.Index`), else each
    # rule's key, "law:element id" ("UK_ukpga_2015_7:section-29" → s.29)
    read =
      if pointers,
        do: Map.new(pointers, fn {l, rs} -> {l, MapSet.new(rs)} end),
        else: rule_refs(changes)

    twins = Map.new(primary, fn p -> {p.key <> "|" <> p.target, twins(p, derived)} end)
    twinned = twins |> Map.values() |> List.flatten() |> MapSet.new(&(&1.key <> "|" <> &1.target))

    value =
      for c <- changes,
          {attribute, {ps, pv}, {ds, dv}} <- c.resolved.conflicts,
          do: %{
            kind: :value,
            target: c.target,
            key: c.key,
            by: c.resolved.by,
            attribute: attribute,
            primary: {ps, pv},
            derived: {ds, dv}
          }

    unjoined =
      for p <- primary,
          ds = twins[p.key <> "|" <> p.target],
          ds != [],
          do: %{
            kind: :unjoined,
            target: p.target,
            key: p.key,
            by: p.resolved.by,
            operation: p.resolved.operation,
            twins: Enum.map(ds, &{&1.key, &1.target, &1.resolved.operation})
          }

    alone = Enum.reject(derived, &MapSet.member?(twinned, &1.key <> "|" <> &1.target))
    {was_read, unread} = Enum.split_with(alone, &read?(&1, read))

    uncovered =
      for(
        p <- primary,
        twins[p.key <> "|" <> p.target] == [],
        do: uncovered(p, :derived)
      ) ++ Enum.map(was_read, &uncovered(&1, :primary))

    unread =
      for d <- unread,
          Map.has_key?(read, d.resolved.by),
          do: %{
            kind: :unread,
            target: d.target,
            key: d.key,
            by: d.resolved.by,
            operation: d.resolved.operation,
            affecting: Change.value(d, :feed, :affecting) || Change.value(d, :markup, :affecting)
          }

    value ++ unjoined ++ uncovered ++ unread
  end

  defp rule_refs(changes) do
    for c <- changes,
        Change.values(c, :law_text, :by) != [],
        [law, id] <- [
          String.split(
            SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw.provision_key(c.key),
            ":",
            parts: 2
          )
        ],
        ref = Order.ref(id),
        ref != nil,
        reduce: %{} do
      acc -> Map.update(acc, law, MapSet.new([ref]), &MapSet.put(&1, ref))
    end
  end

  # one of the amending provisions the feed names was read (it, or a
  # provision containing it)
  defp read?(d, read) do
    refs = Map.get(read, d.resolved.by, MapSet.new())

    # the provisions the feed names, else those its note names (a pointer)
    named = Change.value(d, :feed, :affecting) || Change.value(d, :markup, :affecting) || []

    Enum.any?(named, fn a ->
      Enum.any?(containing(a), &MapSet.member?(refs, &1))
    end)
  end

  # "s.29(4)(a)" → ["s.29(4)(a)", "s.29(4)", "s.29"]; "sch.2.para.3" →
  # ["sch.2.para.3", "sch.2"]
  defp containing(ref) do
    bare = String.replace(ref, ~r/\(.*$/, "")

    brackets =
      Regex.scan(~r/\([^)]+\)/, ref)
      |> List.flatten()
      |> Enum.scan("", &(&2 <> &1))
      |> Enum.map(&(bare <> &1))

    parts = String.split(bare, ".")

    dotted =
      for n <- 2..length(parts)//2,
          n <= length(parts),
          do: parts |> Enum.take(n) |> Enum.join(".")

    Enum.uniq(Enum.reverse(brackets) ++ Enum.reverse(dotted))
  end

  defp uncovered(c, missing),
    do: %{
      kind: :uncovered,
      target: c.target,
      key: c.key,
      by: c.resolved.by,
      operation: c.resolved.operation,
      missing: missing
    }

  # derived-only changes by the same law on the provision, or one above or below it
  defp twins(p, derived) do
    for d <- derived,
        d.resolved.by == p.resolved.by,
        near?(d.target, p.target),
        do: d
  end

  defp near?(a, b), do: a == b or a in LatRef.ancestors(b) or b in LatRef.ancestors(a)

  defp text?(c), do: c.resolved.operation in @text

  # who states the change: the sources claiming the change itself (its
  # operation) — not those filling a gap in it (the amending law's extent
  # or date, added to a record legislation.gov.uk alone states)
  defp tiers(c) do
    c.claims
    |> Enum.filter(&(&1.attribute == :operation))
    |> Enum.map(&Evidence.tier(&1.source))
    |> Enum.uniq()
  end
end
