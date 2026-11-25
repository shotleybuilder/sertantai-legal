defmodule SertantaiLegal.Scraper.StepProcedures.ExtentStale do
  @moduledoc """
  The amending laws whose extent reading is stale: those stored by other
  reader code (`reader_version` not `Extent.ReadVersion.current/0`), and
  those a build reads with their text held but never read (no
  `extent_rules`: `Extent.Store.unread/2`) — the laws behind the
  `:extent_reader` reason (`ChangeVocabulary.Store.Inputs.readers/3`).
  Store-wide, or for the laws a family's builds read: their affecting laws
  and commencement sources (`mix lat.amending --extents --stale`). DB only.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Store, as: ExtentStore
  alias SertantaiLegal.Scraper.ChangeVocabulary.Measures.Source
  alias SertantaiLegal.Scraper.ChangeVocabulary.Store

  @type t :: %{old_code: [String.t()], not_read: [String.t()]}

  @doc "The stale laws, store-wide (`nil`) or for `family`'s builds; each list sorted."
  @spec laws(String.t() | nil) :: t()
  def laws(family \\ nil) do
    builds = Store.builds()
    read = read_laws(builds, family)
    %{old_code: old_code(family && read), not_read: not_read(read)}
  end

  @doc "The two lists as one, sorted."
  @spec all(t()) :: [String.t()]
  def all(%{old_code: o, not_read: n}), do: Enum.sort(o ++ n)

  # the laws the builds read the extent of: every build's, or the family's
  defp read_laws(builds, nil), do: builds |> Map.values() |> extended()

  defp read_laws(builds, family) do
    family |> Source.family_laws() |> Enum.flat_map(&List.wrap(builds[&1])) |> extended()
  end

  defp extended(builds) do
    builds
    |> Enum.flat_map(&((&1.affecting || []) ++ (&1.commencement_sources || [])))
    |> Enum.uniq()
    |> Enum.filter(&ExtentStore.reads?/1)
  end

  defp old_code(laws) do
    {filter, params} = if laws, do: {"AND source_law = ANY($2)", [laws]}, else: {"", []}

    Repo.query!(
      "SELECT DISTINCT source_law FROM extent_rules WHERE reader_version IS DISTINCT FROM $1 #{filter} ORDER BY 1",
      [ReadVersion.current() | params],
      timeout: :infinity
    ).rows
    |> List.flatten()
  end

  defp not_read(laws), do: ExtentStore.unread(laws, ExtentStore.for_laws(laws))
end
