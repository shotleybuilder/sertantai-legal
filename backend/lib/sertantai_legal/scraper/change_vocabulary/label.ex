defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label do
  @moduledoc """
  A provision's label periods folded from its resolved changes (change
  vocabulary, CV-02 slice). The changes that reach a provision: those on it,
  and provision-level changes on its ancestors — never a change on a child
  (C9). In date order, from the provision's start:

  - a repeal takes its territory out of the provision's (everywhere when it
    names none); nothing left → repealed (territory `"nowhere"`, C2);
  - a text change (substituted, inserted, renumbered) where it applies is a
    new version: `in_force_from` its date, `changed_by` every law changing
    the text that day (parallel territorial changes, C5) — D1;
  - consecutive periods that read the same are one.

  Slice limits (CV-05 widens): no commencement beyond the start, no
  prospective or partial status, no gaps. Pure.
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

  @doc "The periods of provision `id` (`%{extent, start}`) from resolved changes."
  @spec fold(String.t(), %{extent: String.t() | nil, start: Date.t()}, [Change.t()]) :: [period()]
  def fold(id, %{extent: extent, start: start}, changes) do
    first = %{
      valid_from: start,
      valid_to: nil,
      status: :in_force,
      in_force_from: start,
      changed_by: [],
      territory: extent
    }

    changes
    |> Enum.filter(&reaches?(&1, id))
    |> Enum.filter(&(&1.resolved.date != nil and Date.compare(&1.resolved.date, start) == :gt))
    |> Enum.group_by(& &1.resolved.date)
    |> Enum.sort_by(&elem(&1, 0), Date)
    |> Enum.reduce([first], fn {date, day}, [current | _] = periods ->
      case apply_day(current, date, day) do
        same when same == current -> periods
        next -> [next, %{current | valid_to: date} | tl(periods)]
      end
    end)
    |> Enum.reverse()
  end

  defp reaches?(%Change{target: target, resolved: r}, id) do
    target == id or (r.level == :provision and target in tl(LatRef.ancestors(id)))
  end

  defp apply_day(%{status: :repealed} = current, _date, _day), do: current

  defp apply_day(current, date, day) do
    repeals = Enum.filter(day, &(&1.resolved.operation == :repealed))

    # a repeal naming no territory reaches everywhere; nil extent is the UK
    territory =
      Enum.reduce(repeals, current.territory, fn
        _c, :gone -> :gone
        %{resolved: %{territory: nil}}, _t -> :gone
        c, t -> Territory.subtract(t || "E+W+S+NI", c.resolved.territory) || :gone
      end)

    versions =
      Enum.filter(
        day,
        &(&1.resolved.operation in @text_changes and overlaps?(&1.resolved.territory, territory))
      )

    cond do
      territory == :gone ->
        %{
          current
          | valid_from: date,
            status: :repealed,
            territory: "nowhere",
            in_force_from: nil,
            changed_by: by(day)
        }

      versions != [] ->
        %{
          current
          | valid_from: date,
            territory: territory,
            in_force_from: date,
            changed_by: by(versions)
        }

      territory != current.territory ->
        %{current | valid_from: date, territory: territory}

      true ->
        current
    end
  end

  defp overlaps?(nil, _territory), do: true
  defp overlaps?(_t, nil), do: true
  defp overlaps?(t, territory), do: not Territory.disjoint?(t, territory)

  defp by(changes),
    do:
      changes
      |> Enum.map(& &1.resolved.by)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.sort()
end
