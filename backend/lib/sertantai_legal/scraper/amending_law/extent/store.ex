defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Store do
  @moduledoc """
  The extent ruleset's table, `extent_rules` (CV-04): an Act's extent
  clause is written together (delete + insert by `source_law`), so it
  always matches its latest reading, and read back as an
  `AmendingLaw.Extent`. DB only — the reading is `AmendingLaw.Extent`.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Powers

  @columns ~w(kind place items position source_law source_ref source_text amends)a
  # what `rows_for/1` reads back, compared before writing
  @compared ~w(kind place items source_ref amends)a

  # the laws whose own extent clause is read: Acts ("this Act extends to")
  # and SIs ("These Regulations extend to", "This Order extends to"; CV-07)
  @types ~w(ukpga asp anaw asc nia apni uksi ssi wsi nisr nisi)

  @doc "True when `law` is of a type whose own extent clause is read."
  @spec reads?(String.t()) :: boolean()
  def reads?(law) do
    case String.split(law || "", "_", parts: 4) do
      [_, type, _, _] -> type in @types
      _ -> false
    end
  end

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
    extent = Powers.with_powers(read, source_law, opts)

    # (the same rows as stored: not written again — a full read pass after
    # a reader change reads most laws' extent unchanged; run time 2026-10-26)
    same? =
      Map.get(rows_for([source_law]), source_law, []) |> MapSet.new() ==
        extent |> Extent.to_rows(source_law) |> Enum.map(&Map.take(&1, @compared)) |> MapSet.new()

    if same? do
      {:ok, length(Extent.to_rows(extent, source_law)), extent}
    else
      {:ok, n} = write(source_law, extent)
      {:ok, n, extent}
    end
  end

  # replace `source_law`'s extent rules with `extent`
  defp write(source_law, %Extent{} = extent) do
    rows = Extent.to_rows(extent, source_law)

    Repo.transaction(fn ->
      Repo.query!("DELETE FROM extent_rules WHERE source_law = $1", [source_law])

      for row <- rows do
        Repo.query!(
          """
          INSERT INTO extent_rules (id, #{Enum.join(@columns, ", ")}, read_at)
          VALUES (gen_random_uuid(), #{1..length(@columns) |> Enum.map_join(", ", &"$#{&1}")}, now())
          """,
          Enum.map(@columns, &Map.fetch!(row, &1))
        )
      end

      length(rows)
    end)
  end

  @doc """
  Each law's stored rows as written (kind, place, items, source_ref, amends), for
  those of `laws` read — what the check compares the reading now with, so
  a row `to_rows/2` loses shows (CV-S05 N9).
  """
  @spec rows_for([String.t()]) :: %{String.t() => [map()]}
  def rows_for(laws) do
    Repo.query!(
      "SELECT source_law, kind, place, items, source_ref, amends FROM extent_rules WHERE source_law = ANY($1)",
      [laws]
    ).rows
    |> Enum.group_by(&hd/1, fn [_, k, p, i, r, a] ->
      %{kind: k, place: p, items: i, source_ref: r, amends: a}
    end)
  end

  @doc "Each law's extent read, for those of `laws` read (absent: not read)."
  @spec for_laws([String.t()]) :: %{String.t() => Extent.t()}
  def for_laws(laws) do
    %{rows: rows, columns: cols} =
      Repo.query!(
        "SELECT #{Enum.join(@columns, ", ")} FROM extent_rules WHERE source_law = ANY($1)",
        [laws]
      )

    rows
    |> Enum.map(
      &(cols
        |> Enum.map(fn c -> String.to_existing_atom(c) end)
        |> Enum.zip(&1)
        |> Map.new())
    )
    |> Enum.group_by(& &1.source_law)
    |> Map.new(fn {law, rs} -> {law, Extent.from_rows(rs)} end)
  end
end
