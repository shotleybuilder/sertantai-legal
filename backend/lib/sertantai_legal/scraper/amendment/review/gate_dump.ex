defmodule SertantaiLegal.Scraper.Amendment.Review.GateDump do
  @moduledoc """
  The amending gate's groups written out for review (Amending-law reader:
  review tooling; it replaces the hand-written `dump_groups.exs`): each
  group's key in `disagreements.json`, cause, amending law, status and
  reach, and up to `per` of its changes as checkable items (the amending
  provision's words, its rules and legislation.gov.uk's record:
  `Amendment.CheckSample.item/2`, passed in). The groups not named come
  first, widest first. Pure: the item function does the reading.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.Commencement.Leftovers

  @type change :: {String.t(), Change.t()}

  @doc """
  The dump over `groups` (`Amendment.Disagreement.groups/2`) with the
  reviewed statuses; `item` makes one change's entry, `per` caps the
  changes shown per group (`:all` for every one).
  """
  @spec dump(
          %{{String.t(), String.t()} => [change()]},
          map(),
          (change(), pos_integer() -> map()),
          pos_integer() | :all
        ) :: [map()]
  def dump(groups, reviewed, item, per) do
    groups
    |> Enum.map(fn {{cause, by}, changes} ->
      status = Leftovers.status(cause, reviewed, by)

      %{
        "key" => "#{cause} @ #{by}",
        "cause" => cause,
        "amending_law" => by,
        "status" => status,
        "named" => Leftovers.named?(status),
        "reach" => length(changes),
        "changes" =>
          changes |> take(per) |> Enum.with_index(1) |> Enum.map(fn {c, i} -> item.(c, i) end)
      }
    end)
    |> Enum.sort_by(&{&1["named"], -&1["reach"], &1["key"]})
  end

  defp take(changes, :all), do: changes
  defp take(changes, n), do: Enum.take(changes, n)
end
