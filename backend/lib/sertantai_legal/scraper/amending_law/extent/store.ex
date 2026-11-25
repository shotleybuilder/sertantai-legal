defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Store do
  @moduledoc """
  The extent ruleset's table, `extent_rules` (CV-04): an Act's extent
  clause is written together (delete + insert by `source_law`), so it
  always matches its latest reading, and read back as an
  `AmendingLaw.Extent`. Each row is stamped with the reader code that read
  it (`Extent.ReadVersion`, #193). DB only — the reading is
  `Extent.Reader`, and the write with its powers placed is `Extent.Write`,
  so the build's reads (`for_laws/1`) reach no reader code.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Extent
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion
  alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

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
  Re-stamp a law's stored rows with this reader code, where they differ
  (read again by it, the same: `Extent.Write`). `read_at` is kept, so no
  rebuild follows.
  """
  @spec stamp(String.t()) :: :ok
  def stamp(source_law) do
    Repo.query!(
      "UPDATE extent_rules SET reader_version = $2 WHERE source_law = $1 AND reader_version IS DISTINCT FROM $2",
      [source_law, ReadVersion.current()]
    )

    :ok
  end

  @doc "Replace `source_law`'s extent rules with `extent`'s rows: `{:ok, count}`."
  @spec write(String.t(), Extent.t()) :: {:ok, non_neg_integer()}
  def write(source_law, %Extent{} = extent) do
    rows = Extent.to_rows(extent, source_law)

    Repo.transaction(fn ->
      Repo.query!("DELETE FROM extent_rules WHERE source_law = $1", [source_law])

      for row <- rows do
        Repo.query!(
          """
          INSERT INTO extent_rules (id, #{Enum.join(@columns, ", ")}, read_at, reader_version)
          VALUES (gen_random_uuid(), #{1..length(@columns) |> Enum.map_join(", ", &"$#{&1}")}, now(), $#{length(@columns) + 1})
          """,
          Enum.map(@columns, &Map.fetch!(row, &1)) ++ [ReadVersion.current()]
        )
      end

      length(rows)
    end)
  end

  @doc "The columns a stored row is compared on (`rows_for/1`'s), for a reading's rows."
  @spec compared() :: [atom()]
  def compared, do: @compared

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

  @doc """
  Those of `laws` whose extent is not read (`extents`: `for_laws/1`'s) but
  could be: their text is held. Sorted. A law read with nothing to say has
  a `none` row, so absent is never "read, silent".
  """
  @spec unread([String.t()], %{String.t() => Extent.t()}) :: [String.t()]
  def unread(laws, extents) do
    laws
    |> Enum.reject(&Map.has_key?(extents, &1))
    |> Enum.filter(&(ClmlStore.law_files(&1) != []))
    |> Enum.sort()
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
