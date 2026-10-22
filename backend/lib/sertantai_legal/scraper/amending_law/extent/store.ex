defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Store do
  @moduledoc """
  The extent ruleset's table, `extent_rules` (CV-04): an Act's extent
  clause is written together (delete + insert by `source_law`), so it
  always matches its latest reading, and read back as an
  `AmendingLaw.Extent`. DB only — the reading is `AmendingLaw.Extent`.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.Extent

  @columns ~w(kind place items position source_law source_ref source_text)a

  # the Acts with an extent clause to read (their own legislatures' Acts)
  @act_types ~w(ukpga asp anaw asc nia apni)

  @doc "True when `law` is an Act, whose extent clause is read."
  @spec act?(String.t()) :: boolean()
  def act?(law) do
    case String.split(law || "", "_", parts: 4) do
      [_, type, _, _] -> type in @act_types
      _ -> false
    end
  end

  @doc "Replace `source_law`'s extent rules with its extent read. Returns `{:ok, count}`."
  @spec write(String.t(), Extent.t()) :: {:ok, non_neg_integer()}
  def write(source_law, %Extent{} = extent) do
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
