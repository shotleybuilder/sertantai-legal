defmodule SertantaiLegal.Scraper.LatTitles do
  @moduledoc """
  Title-only rollout of the LAT `title` column (LAT parser coverage II):
  which stored rows need their title set, changed or cleared to match a fresh
  parse. Rows are matched on `section_id`; a row only one side has is left
  for a re-parse (no inserts, no deletes, row text never touched).

  Pure: takes the stored and parsed rows, returns `{section_id, title}`
  updates. `mix lat.backfill_titles` does the I/O.
  """

  @type row :: %{required(:section_id) => String.t(), required(:title) => String.t() | nil}

  @doc "Updates that bring the stored rows' titles in line with the parse, in stored order."
  @spec plan([row()], [row()]) :: [{String.t(), String.t() | nil}]
  def plan(stored, parsed) do
    titles = Map.new(parsed, &{&1.section_id, &1.title})

    for %{section_id: id, title: old} <- stored,
        Map.has_key?(titles, id),
        (new = titles[id]) != old,
        do: {id, new}
  end
end
