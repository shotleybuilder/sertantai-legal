defmodule SertantaiLegal.Scraper.Commencement.Store do
  @moduledoc """
  The commencement ruleset's table, `commencement_rules` (CR-01): a source
  document's rules are written together (delete + insert by `source_law`),
  so they always match its latest reading; a law's rules are read back as
  `Rule` structs. DB only — the rules themselves are `Commencement.Rule`.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Commencement.Rule

  @columns ~w(commences scope_kind scope scope_except when_kind when_date when_basis when_offset
              when_detail territory purposes source_law source_ref source_text treatment)a

  @doc "Replace the rules read from `source_law` with `rules`. Returns `{:ok, count}`."
  @spec write(String.t(), [Rule.t()]) :: {:ok, non_neg_integer()}
  def write(source_law, rules) do
    for r <- rules, r.source.law != source_law do
      raise ArgumentError, "rule from #{r.source.law} written as #{source_law}'s"
    end

    rows = Enum.map(rules, &Rule.to_row/1)

    Repo.transaction(fn ->
      Repo.query!("DELETE FROM commencement_rules WHERE source_law = $1", [source_law])

      for row <- rows do
        Repo.query!(
          """
          INSERT INTO commencement_rules (#{Enum.join(@columns, ", ")})
          VALUES (#{1..length(@columns) |> Enum.map_join(", ", &"$#{&1}")})
          """,
          Enum.map(@columns, &Map.fetch!(row, &1))
        )
      end

      length(rows)
    end)
  end

  @doc "The rules bringing `law_name`'s provisions into force, from every source."
  @spec for_law(String.t()) :: [Rule.t()]
  def for_law(law_name) do
    %{rows: rows, columns: cols} =
      Repo.query!(
        """
        SELECT #{Enum.join(@columns, ", ")} FROM commencement_rules
        WHERE commences = $1 ORDER BY source_law, source_ref, read_at
        """,
        [law_name]
      )

    for r <- rows do
      cols |> Enum.map(&String.to_existing_atom/1) |> Enum.zip(r) |> Map.new() |> Rule.from_row()
    end
  end
end
