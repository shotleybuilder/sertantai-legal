defmodule SertantaiLegal.Scraper.EnactedBy.EnablingExtent do
  @moduledoc """
  The extent of an SI's enabling provisions (`EnablingProvisions`), from the
  parent Acts' LAT `extent_code`: the named sections' rows (body, not
  schedules) and the named schedules' rows. Feeds `ExtentResolver`'s
  `enabling_provisions` source.

  All-or-nothing: if any named section or schedule has no coded LAT row (the
  parent holds no LAT, or the provision is missing), there is no verdict —
  a partial union would understate the SI's reach.
  """

  alias SertantaiLegal.Repo

  @doc "Extent codes of the provisions `%{\"provisions\" => [...]}`; nil when incomplete."
  @spec extents(map() | nil) :: [String.t()] | nil
  def extents(%{"provisions" => [_ | _] = provisions}) do
    results = Enum.map(provisions, &provision_extents/1)
    if Enum.any?(results, &is_nil/1), do: nil, else: results |> List.flatten() |> Enum.uniq()
  end

  def extents(_), do: nil

  defp provision_extents(%{"law" => law} = p) do
    sections = Map.get(p, "sections", [])
    schedules = Map.get(p, "schedules", [])

    %{rows: rows} =
      Repo.query!(
        """
        SELECT CASE WHEN schedule IS NULL THEN 's:' || provision ELSE 'sch:' || schedule END, extent_code
        FROM legal_articles
        WHERE law_name = $1 AND coalesce(extent_code, '') <> ''
          AND ((schedule IS NULL AND provision = ANY($2)
                AND section_type IN ('section', 'article', 'regulation', 'rule'))
               OR schedule = ANY($3))
        """,
        [law, sections, schedules]
      )

    found = rows |> Enum.map(&hd/1) |> MapSet.new()
    wanted = Enum.map(sections, &"s:#{&1}") ++ Enum.map(schedules, &"sch:#{&1}")

    if Enum.all?(wanted, &MapSet.member?(found, &1)),
      do: rows |> Enum.map(&List.last/1) |> Enum.uniq(),
      else: nil
  end
end
