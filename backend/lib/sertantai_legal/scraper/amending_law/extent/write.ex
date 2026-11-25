defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Write do
  @moduledoc """
  The one way a law's extent reading is written to `extent_rules`: the
  reading with its powers placed (`Extent.Powers`), compared with the rows
  stored, written only where they differ, else re-stamped (`Extent.Store`).
  Split from `Extent.Store` (the Extent reader stamps session) so the
  build's reads of the store reach none of the powers placement.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Powers, Store}

  @doc """
  Store a law's extent as read (`Extent.read/1`), with what it extends to
  where it states none — an SI's enabling powers, else its legislature's
  competence (`Powers.with_powers/3`; `cached: true` never fetches) — as
  `mix lat.extent_check` reads it. The one way `extent_rules` are written
  (`ExtentWriteTest`): the amendment read pass once stored the bare
  reading, wiping 482 laws' powers and competence rows (run time,
  2026-10-26). Rows the same as stored are left as they are. Returns
  `{:ok, count, extent}`, the extent stored.
  """
  @spec write_read(String.t(), Extent.t(), keyword()) ::
          {:ok, non_neg_integer(), Extent.t()}
  def write_read(source_law, %Extent{} = read, opts \\ []) do
    plan = plan(source_law, read, opts)

    # (the same rows as stored: not written again — a full read pass after
    # a reader change reads most laws' extent unchanged; run time 2026-10-26)
    if plan.same? do
      # read again by this code, the same: stamped, read_at kept (no rebuild)
      :ok = Store.stamp(source_law)
      {:ok, length(plan.rows), plan.extent}
    else
      {:ok, n} = Store.write(source_law, plan.extent)
      {:ok, n, plan.extent}
    end
  end

  @type plan :: %{extent: Extent.t(), stored: [map()], rows: [map()], same?: boolean()}

  @doc """
  What `write_read/3` would do, with nothing written: the extent with its
  powers placed, the rows stored and the reading's rows (on
  `Store.compared/0`'s columns), and whether they are the same
  (`mix lat.amending --extents --preview`).
  """
  @spec plan(String.t(), Extent.t(), keyword()) :: plan()
  def plan(source_law, %Extent{} = read, opts \\ []) do
    extent = Powers.with_powers(read, source_law, opts)
    stored = Map.get(Store.rows_for([source_law]), source_law, [])

    rows =
      extent |> Extent.to_rows(source_law) |> Enum.map(&Map.take(&1, Store.compared()))

    %{extent: extent, stored: stored, rows: rows, same?: MapSet.new(stored) == MapSet.new(rows)}
  end
end
