defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Facts do
  @moduledoc """
  What the label fold reads off resolved changes (change vocabulary,
  CV-S09): territory arithmetic, the laws a field credits, a commencement
  for one territory (C13), and each field's tier. Shared by `Label.Start`
  and `Label.Day`. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.Territory

  @text_changes [:substituted, :inserted, :renumbered]

  @doc "The operations that change a provision's text."
  @spec text_changes() :: [atom()]
  def text_changes, do: @text_changes

  @doc """
  The laws behind a version (D1): the laws making the text, the law itself
  none. For a commencement, the law bringing it into force (`Change.credit/1`).
  """
  @spec by([Change.t()], String.t() | nil) :: [String.t()]
  def by(changes, self),
    do:
      changes
      |> Enum.map(&Change.credit/1)
      |> clean(self)

  @doc "The laws that made the changes' text (`by`), the law itself none."
  @spec makers([Change.t()], String.t() | nil) :: [String.t()]
  def makers(changes, self), do: changes |> Enum.map(& &1.resolved.by) |> clean(self)

  @doc """
  The laws that brought the changes into force apart from the laws in
  `makers` and the law itself (Jason 2026-10-30: `commenced_by` its own
  label): a commencing order (SI 1974/1439 for HSWA s.78; SI 2004/2173 for
  CROW s.13), none when the law commenced itself.
  """
  @spec commencers([Change.t()], [String.t()], String.t() | nil) :: [String.t()]
  def commencers(changes, makers, self),
    do:
      changes
      |> Enum.map(fn c ->
        if c.resolved.operation == :commenced,
          do: c.resolved.commenced_by || c.resolved.by,
          else: c.resolved.commenced_by
      end)
      |> clean(self)
      |> Enum.reject(&(&1 in makers))

  defp clean(laws, self),
    do: laws |> Enum.reject(&(&1 == nil or same_law?(&1, self))) |> Enum.uniq() |> Enum.sort()

  @doc """
  True for the same instrument: legislation.gov.uk serves a Welsh SI both
  as `wsi` and as `uksi` under its one UK SI number (SI 2017/544: its own
  commencement read as UK_wsi_2017_544, the golden law UK_uksi_2017_544).
  Only that pair: other series number apart (memory: UK law identity).
  """
  @spec same_law?(String.t() | nil, String.t() | nil) :: boolean()
  def same_law?(a, b) when is_binary(a) and is_binary(b), do: welsh(a) == welsh(b)
  def same_law?(_a, _b), do: false

  defp welsh(law), do: String.replace(law, "_wsi_", "_uksi_")

  @doc """
  The territory a commencement (or a staged insertion's first stage) is
  for, when that is all its qualification limits ("for E.", an order
  applying in England only): in force there (C13). nil otherwise — a
  partial commencement for purposes stays partial.
  """
  @spec territory_only(Change.t()) :: String.t() | nil
  def territory_only(c) do
    with t when is_binary(t) <- Change.value(c, :feed, :in_force_for),
         q when q in [nil, "territory"] <- Change.value(c, :feed, :qualification) do
      t
    else
      _ -> nil
    end
  end

  @doc """
  True for a dated change the markup marks in the provision's text with no
  operation of its own — a legacy Addition inside the text claims none
  (CV-S08, Jason 2026-10-29), yet its words changed: a version (CV-S09
  round 2: Factories Act 1961 s.125(6), SI 1988/1655). A feed
  modification or application carries no markup, so never.
  """
  @spec marked_text?(Change.t()) :: boolean()
  def marked_text?(%Change{resolved: r} = c),
    do:
      r.operation == nil and r.level == :words and r.date != nil and
        Enum.any?(c.claims, &(&1.source == :markup))

  @doc "True for an amendment to an earlier amending provision (the feed's \"… in earlier amending provision\")."
  @spec earlier_amendment?(Change.t()) :: boolean()
  def earlier_amendment?(c), do: Change.value(c, :feed, :earlier_amendment) == true

  @doc "True for a commencement that brings the provision fully into force where it reaches."
  @spec full?(Change.t()) :: boolean()
  def full?(c), do: not c.resolved.partial or territory_only(c) != nil

  @doc "`a` narrowed to `b`."
  @spec intersect(String.t(), String.t()) :: String.t()
  def intersect(a, b), do: Territory.subtract(a, Territory.subtract(a, b) || "") || a

  @doc "Where it applies once an application clause reaching `t` takes effect (C6)."
  @spec apply_to(String.t() | nil | :gone, String.t() | nil) :: String.t() | nil | :gone
  def apply_to(:gone, _t), do: :gone
  def apply_to(territory, nil), do: territory
  def apply_to(nil, t), do: t
  def apply_to(territory, t), do: intersect(territory, t)

  @doc "Where it remains after whole-provision repeals; a repeal naming no territory reaches everywhere."
  @spec after_repeals(String.t() | nil | :gone, [Change.t()]) :: String.t() | nil | :gone
  def after_repeals(territory, repeals) do
    Enum.reduce(repeals, territory, fn
      _c, :gone -> :gone
      %{resolved: %{territory: nil}}, _t -> :gone
      # where it extends is unknown: a repeal leaves no remainder to invent
      # (CV-S09 round 2: SI 1987/605, revoked E+W+S, had read in force NI)
      _c, nil -> :gone
      c, t -> Territory.subtract(t, c.resolved.territory) || :gone
    end)
  end

  @doc "True unless both territories are known and disjoint."
  @spec overlaps?(String.t() | nil, String.t() | nil) :: boolean()
  def overlaps?(nil, _territory), do: true
  def overlaps?(_t, nil), do: true
  # nothing left (a whole repeal the same day): no change applies
  def overlaps?(_t, :gone), do: false
  def overlaps?(t, territory), do: not Territory.disjoint?(t, territory)

  # each field's tier from the attributes that set it, over the changes
  # that set it: derived when any is, primary when all stated are, nil
  # when no source states them (CV-04: a field rests on its own evidence,
  # not on any attribute of the change)
  @field_attributes %{
    status: [:operation, :date, :partial],
    # where it applies rests on the change itself when it names no
    # territory ("nowhere" after a repeal; a revival): CV-S09 round 4
    territory: [:territory, :operation],
    in_force_from: [:date],
    changed_by: [:by],
    commenced_by: [:commenced_by, :by]
  }

  # a commencement found through a pointer (the feed's or a note's: the
  # law's own text at the provision legislation.gov.uk names) rests on
  # legislation.gov.uk for its place: derived (CV-S09 round 3)
  defp pointed(c, a, :primary) when a in [:date, :commenced_by] do
    if Change.value(c, :commencement, :via) in [:note, :feed], do: :derived, else: :primary
  end

  defp pointed(_c, _a, t), do: t

  @doc "The period's tiers with `fields` set from `changes`."
  @spec tiers(map(), [atom()], [Change.t()]) :: map()
  def tiers(current, fields, changes) do
    Enum.reduce(fields, current, fn field, acc ->
      stated =
        for c <- changes,
            a <- Map.fetch!(@field_attributes, field),
            t = Map.get(c.resolved.tiers, a),
            t != nil,
            uniq: true,
            do: pointed(c, a, t)

      # a territory one commencement is for is the feed's word (C13)
      stated =
        if field == :territory and Enum.any?(changes, &territory_only/1),
          do: [:derived | stated],
          else: stated

      tier =
        cond do
          :derived in stated -> :derived
          :primary in stated -> :primary
          true -> nil
        end

      Map.put(acc, field, tier)
    end)
  end
end
