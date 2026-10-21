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
  - **Repeal.** A repeal takes its territory out of the provision's
    (everywhere when it names none); nothing left → repealed, territory
    `"nowhere"` (C2), `changed_by` the repealing laws.
  - **Removal in part** ("revoked in part"): never a whole removal; an
    in-force provision is then partly in force (C7).
  - **Text change** (substituted, inserted, renumbered) where it applies:
    a new version, `in_force_from` its date, `changed_by` every law
    changing the text that day (C5) — D1.
  - `in_force_from` / `changed_by` are empty while prospective or partly
    in force (D1). A day that changes nothing opens no period.

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
          territory: String.t() | nil
        }

  @type provision :: %{
          required(:extent) => String.t() | nil,
          required(:start) => Date.t(),
          optional(:law) => String.t(),
          optional(:prospective) => boolean()
        }

  @doc "The periods of provision `id` from resolved changes."
  @spec fold(String.t(), provision(), [Change.t()]) :: [period()]
  def fold(id, %{start: start} = provision, changes) do
    reaching =
      changes
      |> Enum.filter(&reaches?(&1, id))
      |> Enum.filter(&(&1.resolved.date != nil))

    later? = &(Date.compare(&1.resolved.date, start) == :gt)

    prospective? =
      Map.get(provision, :prospective, false) or
        Enum.any?(reaching, &(&1.resolved.operation == :commenced and later?.(&1)))

    first = %{
      valid_from: start,
      valid_to: nil,
      status: if(prospective?, do: :prospective, else: :in_force),
      in_force_from: if(prospective?, do: nil, else: start),
      changed_by: [],
      territory: provision.extent
    }

    self = Map.get(provision, :law)

    reaching
    |> Enum.filter(later?)
    |> Enum.group_by(& &1.resolved.date)
    |> Enum.sort_by(&elem(&1, 0), Date)
    |> Enum.reduce([first], fn {date, day}, [current | rest] ->
      case apply_day(current, date, day, self) do
        same when same == current -> [current | rest]
        next -> [%{next | valid_from: date}, %{current | valid_to: date} | rest]
      end
    end)
    |> Enum.reverse()
  end

  defp reaches?(%Change{target: target, resolved: r}, id) do
    target == id or (r.level == :provision and target in tl(LatRef.ancestors(id)))
  end

  defp apply_day(%{status: :repealed} = current, _date, _day, _self), do: current

  defp apply_day(current, date, day, self) do
    of = fn op -> Enum.filter(day, &(&1.resolved.operation == op)) end
    commenced = of.(:commenced)
    territory = after_repeals(current.territory, of.(:repealed))

    versions =
      Enum.filter(
        day,
        &(&1.resolved.operation in @text_changes and overlaps?(&1.resolved.territory, territory))
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
      territory == :gone ->
        %{
          current
          | status: :repealed,
            territory: "nowhere",
            in_force_from: nil,
            changed_by: by(of.(:repealed), self)
        }

      status in [:prospective, :in_force_partial] ->
        %{current | status: status, territory: territory, in_force_from: nil, changed_by: []}

      versions != [] or (commenced != [] and status != current.status) ->
        %{
          current
          | status: status,
            territory: territory,
            in_force_from: date,
            changed_by: by(versions ++ commenced, self)
        }

      true ->
        %{current | territory: territory}
    end
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
