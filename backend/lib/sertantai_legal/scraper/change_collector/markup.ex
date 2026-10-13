defmodule SertantaiLegal.Scraper.ChangeCollector.Markup do
  @moduledoc """
  The markup collector (lat-refactor LR-23): change markup in our CLML that
  no changes-feed effect explains (a ChangeId joining no effect, after the
  LR-19 orphan joins). A change happened — the operation is in the markup —
  but no source here says when or by which law: `effective_from` and
  `affecting_law` stay empty, and the record is a visible gap. The
  commentary ref is the `pointer`. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeCollector.Record

  @doc "Records from parsed `rows` (`section_id`, `unjoined_changes`)."
  @spec records(String.t(), [map()]) :: [Record.t()]
  def records(law_name, rows) do
    for row <- rows,
        {change_id, ref, operation} <- Map.get(row, :unjoined_changes) || [] do
      %Record{
        law_name: law_name,
        section_id: row.section_id,
        via: ["markup"],
        pointer: ref,
        source: "markup",
        evidence: change_id,
        operation: operation
      }
    end
  end
end
