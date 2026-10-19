defmodule SertantaiLegal.Scraper.Amendment.Store do
  @moduledoc """
  The amendment ruleset's table, `amendment_rules` (amendment-rules AR-01):
  a source document's rules are written together (delete + insert by
  `source_law`), so they always match its latest reading; a law's rules are
  read back as `Rule` structs. DB only — the rules themselves are
  `Amendment.Rule`.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Amendment.Rule

  @columns ~w(amends targets operation level source_law source_ref source_text treatment)a

  @doc "Replace the rules read from `source_law` with `rules`. Returns `{:ok, count}`."
  @spec write(String.t(), [Rule.t()]) :: {:ok, non_neg_integer()}
  def write(source_law, rules) do
    for r <- rules, r.source.law != source_law do
      raise ArgumentError, "rule from #{r.source.law} written as #{source_law}'s"
    end

    rows = Enum.map(rules, &Rule.to_row/1)

    Repo.transaction(fn ->
      Repo.query!("DELETE FROM amendment_rules WHERE source_law = $1", [source_law])

      for row <- rows do
        Repo.query!(
          """
          INSERT INTO amendment_rules (#{Enum.join(@columns, ", ")})
          VALUES (#{1..length(@columns) |> Enum.map_join(", ", &"$#{&1}")})
          """,
          Enum.map(@columns, &Map.fetch!(row, &1))
        )
      end

      length(rows)
    end)
  end

  @doc "The rules amending `law_name`, from every source."
  @spec for_law(String.t()) :: [Rule.t()]
  def for_law(law_name) do
    %{rows: rows, columns: cols} =
      Repo.query!(
        """
        SELECT #{Enum.join(@columns, ", ")} FROM amendment_rules
        WHERE amends = $1 ORDER BY source_law, source_ref, read_at
        """,
        [law_name]
      )

    for r <- rows do
      cols |> Enum.map(&String.to_existing_atom/1) |> Enum.zip(r) |> Map.new() |> Rule.from_row()
    end
  end
end
