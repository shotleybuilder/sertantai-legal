defmodule SertantaiLegal.Scraper.LatTitles do
  @moduledoc """
  Column-only rollout of parser-derived LAT columns (LAT parser coverage II:
  `title`, `excluded_extent`): which stored rows need the value set, changed
  or cleared to match a fresh parse. Rows are matched on `section_id`; a row only one side has is left
  for a re-parse (no inserts, no deletes, row text never touched).

  Pure: takes the stored and parsed rows, returns `{section_id, title}`
  updates. `mix lat.backfill_titles` does the I/O.
  """

  @type row :: %{required(:section_id) => String.t(), required(:title) => String.t() | nil}

  @doc """
  Updates that bring the stored rows' `field` (default `:title`; also
  `:excluded_extent`) in line with the parse, in stored order.
  """
  @spec plan([map()], [map()], atom()) :: [{String.t(), String.t() | nil}]
  def plan(stored, parsed, field \\ :title) do
    values = Map.new(parsed, &{&1.section_id, Map.get(&1, field)})

    for %{section_id: id} = row <- stored,
        Map.has_key?(values, id),
        (new = values[id]) != Map.get(row, field),
        do: {id, new}
  end
end
