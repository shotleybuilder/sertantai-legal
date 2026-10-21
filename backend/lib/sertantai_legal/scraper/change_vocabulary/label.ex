defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label do
  @moduledoc """
  A provision's label periods folded from its resolved changes (change
  vocabulary). The changes that reach a provision: those on it, and
  provision-level changes on its ancestors — never a change on a child
  (C9). From the provision's start, in date order:

  - **Commencement.** A provision is prospective from its start while a
    commencement reaches it later, or while the markup marks it
    prospective. A full commencement puts it in force; a partial one,
    partly in force. A commencement is a version (D1): `in_force_from` its
    date, `changed_by` its law (none for the law itself).
  - **Repeal.** Words repealed are a text change (below). A whole-provision
    repeal takes its territory out of the provision's
    (everywhere when it names none); nothing left → repealed, territory
    `"nowhere"` (C2), `changed_by` the repealing laws.
  - **Removal in part** ("revoked in part"): never a whole removal; an
    in-force provision is then partly in force (C7).
  - **Text change** (substituted, inserted, renumbered) where it applies:
    a new version, `in_force_from` its date, `changed_by` every law
    changing the text that day (C5) — D1.
  - `in_force_from` / `changed_by` are empty while prospective or partly
    in force (D1). A day that changes nothing opens no period.
  - **Tier** (Jason 2026-10-21): each period's `tiers` say, per field,
    whether it rests on the legal text (`:primary`) or on legislation.gov.uk
    (`:derived`) — derived when any change behind it is; the start's from
    the provision (`:start_tier`).

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.{LatRef, Territory}

  @text_changes [:substituted, :inserted, :renumbered]

  @type period :: %{
          valid_from: Date.t(),
          valid_to: Date.t() | nil,
          status: atom(),
          in_force_from: Date.t() | nil,
          changed_by: [String.t()],
          territory: String.t() | nil,
          tiers: %{atom() => :primary | :derived | nil}
        }

  @type provision :: %{
          required(:extent) => String.t() | nil,
          required(:start) => Date.t(),
          optional(:law) => String.t(),
          optional(:prospective) => boolean(),
          optional(:start_dated) => boolean(),
          optional(:start_tier) => :primary | :derived,
          optional(:version) => String.t()
        }

  @doc "The periods of provision `id` from resolved changes."
  @spec fold(String.t(), provision(), [Change.t()]) :: [period()]
  def fold(id, %{start: start} = provision, changes) do
    version = Map.get(provision, :version)

    # a territorial version takes only the changes that can apply to it
    reaching =
      changes
      |> Enum.filter(&reaches?(&1, id))
      |> Enum.filter(&(&1.resolved.date != nil))
      |> Enum.filter(&(version == nil or overlaps?(&1.resolved.territory, version)))

    later? = &(Date.compare(&1.resolved.date, start) == :gt)

    prospective? =
      Map.get(provision, :prospective, false) or
        Enum.any?(reaching, &(&1.resolved.operation == :commenced and later?.(&1)))

    self = Map.get(provision, :law)

    # the text in force at the start: the original, or the law that
    # inserted or substituted it that day (D1); none when the start's date
    # is not known (C10: commenced by an order we don't hold)
    made_by =
      reaching
      |> Enum.filter(
        &(Date.compare(&1.resolved.date, start) == :eq and &1.resolved.operation in @text_changes)
      )
      |> by(self)

    dated? = Map.get(provision, :start_dated, true)

    first = %{
      valid_from: start,
      valid_to: nil,
      status: if(prospective?, do: :prospective, else: :in_force),
      in_force_from: if(prospective? or not dated?, do: nil, else: start),
      changed_by: if(prospective?, do: [], else: made_by),
      territory: provision.extent,
      tiers:
        Map.new(
          ~w(status in_force_from changed_by territory)a,
          &{&1, Map.get(provision, :start_tier)}
        )
    }

    reaching
    |> Enum.filter(later?)
    |> Enum.group_by(& &1.resolved.date)
    |> Enum.sort_by(&elem(&1, 0), Date)
    |> Enum.reduce([first], fn {date, day}, [current | rest] ->
      next = apply_day(current, date, day, self) |> split(day, version)

      # a day that changes no label field opens no period
      if Map.delete(next, :tiers) == Map.delete(current, :tiers),
        do: [current | rest],
        else: [%{next | valid_from: date}, %{current | valid_to: date} | rest]
    end)
    |> Enum.reverse()
  end

  # its own changes; provision-level changes on an ancestor, or on the
  # whole law ("*")
  defp reaches?(%Change{target: target, resolved: r}, id) do
    target == id or
      (r.level == :provision and (target == "*" or target in tl(LatRef.ancestors(id))))
  end

  defp apply_day(%{status: :repealed} = current, _date, _day, _self), do: current

  defp apply_day(current, date, day, self) do
    of = fn op -> Enum.filter(day, &(&1.resolved.operation == op)) end
    commenced = of.(:commenced)

    # a whole-provision repeal removes it (where it applies); words repealed
    # change its text — a version, as any other text change
    {removals, word_repeals} = Enum.split_with(of.(:repealed), &(&1.resolved.level == :provision))
    territory = after_repeals(current.territory, removals)

    versions =
      Enum.filter(
        day,
        &((&1.resolved.operation in @text_changes or &1 in word_repeals) and
            overlaps?(&1.resolved.territory, territory))
      )

    # a removal in part leaves an in-force provision partly in force (C7);
    # a prospective one stays prospective
    in_part? = of.(:repealed_in_part) != []

    status =
      cond do
        Enum.any?(commenced, &(not &1.resolved.partial)) -> :in_force
        commenced != [] and current.status == :prospective -> :in_force_partial
        in_part? and current.status == :in_force -> :in_force_partial
        true -> current.status
      end

    cond do
      # repealed with savings: saved where it was in force (D3)
      territory == :gone and Enum.any?(removals, & &1.resolved.saved) ->
        %{
          current
          | tiers: tiers(current.tiers, [:status, :in_force_from, :changed_by], removals),
            status: :repealed_saved,
            in_force_from: nil,
            changed_by: by(removals, self)
        }

      territory == :gone ->
        %{
          current
          | tiers:
              tiers(current.tiers, [:status, :territory, :in_force_from, :changed_by], removals),
            status: :repealed,
            territory: "nowhere",
            in_force_from: nil,
            changed_by: by(removals, self)
        }

      status in [:prospective, :in_force_partial] ->
        %{
          current
          | status: status,
            territory: territory,
            in_force_from: nil,
            changed_by: [],
            tiers: tiers(current.tiers, [:status, :territory], day)
        }

      versions != [] or (commenced != [] and status != current.status) ->
        %{
          current
          | tiers:
              tiers(
                current.tiers,
                [:status, :territory, :in_force_from, :changed_by],
                versions ++ commenced ++ removals
              ),
            status: status,
            territory: territory,
            in_force_from: date,
            changed_by: by(versions ++ commenced, self)
        }

      territory != current.territory ->
        %{current | territory: territory, tiers: tiers(current.tiers, [:territory], removals)}

      true ->
        current
    end
  end

  # a territorial version splits from its base when a text change confined
  # to its territory takes effect: from then, its own territory (C3)
  defp split(period, _day, nil), do: period
  defp split(%{status: s} = period, _day, _v) when s in [:repealed, :repealed_saved], do: period

  defp split(period, day, version) do
    confined? =
      Enum.any?(day, fn c ->
        c.resolved.operation in @text_changes and c.resolved.territory != nil and
          Territory.covers?(version, c.resolved.territory)
      end)

    if confined? and is_binary(period.territory),
      do: %{period | territory: intersect(period.territory, version)},
      else: period
  end

  defp intersect(a, b), do: Territory.subtract(a, Territory.subtract(a, b) || "") || a

  # the fields' tier from the changes that set them: derived when any is
  defp tiers(current, fields, changes) do
    tier =
      if Enum.any?(changes, &Enum.any?(Map.values(&1.resolved.tiers), fn t -> t == :derived end)),
        do: :derived,
        else: :primary

    Enum.reduce(fields, current, &Map.put(&2, &1, tier))
  end

  # a repeal naming no territory reaches everywhere; nil extent is the UK
  defp after_repeals(territory, repeals) do
    Enum.reduce(repeals, territory, fn
      _c, :gone -> :gone
      %{resolved: %{territory: nil}}, _t -> :gone
      c, t -> Territory.subtract(t || "E+W+S+NI", c.resolved.territory) || :gone
    end)
  end

  defp overlaps?(nil, _territory), do: true
  defp overlaps?(_t, nil), do: true
  defp overlaps?(t, territory), do: not Territory.disjoint?(t, territory)

  # the laws behind a version; the law itself is none (D1)
  defp by(changes, self),
    do:
      changes
      |> Enum.map(& &1.resolved.by)
      |> Enum.reject(&(&1 == nil or &1 == self))
      |> Enum.uniq()
      |> Enum.sort()
end
