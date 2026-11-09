defmodule SertantaiLegal.Scraper.Commencement.Store do
  @moduledoc """
  The commencement ruleset's table, `commencement_rules` (CR-01): a source
  document's rules are written together (delete + insert by `source_law`),
  so they always match its latest reading; a law's rules are read back as
  `Rule` structs. Each row is stamped with the reader code that read it
  (`Commencement.ReadVersion`, #193). DB only — the rules themselves are
  `Commencement.Rule`.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Commencement.{ReadVersion, Rule}

  @columns ~w(commences scope_kind scope scope_except when_kind when_date when_basis when_offset
              when_detail territory purposes source_law source_ref source_text treatment)a

  @doc """
  Replace the rules read from `source_law` with `rules`. Returns `{:ok,
  count}`. `treatments:` replaces only rules of those treatments — two
  readers of one document (its feed effects, its text) keep each other's.
  `commences:` replaces only its rules for that law — an order read for one
  law keeps its rules for another (SI 1996/186, read for SI 1996/1030 as
  well as for the Environment Act 1995).
  """
  @spec write(String.t(), [Rule.t()], keyword()) :: {:ok, non_neg_integer()}
  def write(source_law, rules, opts \\ []) do
    for r <- rules, r.source.law != source_law do
      raise ArgumentError, "rule from #{r.source.law} written as #{source_law}'s"
    end

    rows = Enum.map(rules, &Rule.to_row/1)

    Repo.transaction(fn ->
      delete(source_law, Keyword.get(opts, :treatments), Keyword.get(opts, :commences))

      for row <- rows do
        Repo.query!(
          """
          INSERT INTO commencement_rules (#{Enum.join(@columns, ", ")}, reader_version)
          VALUES (#{1..(length(@columns) + 1) |> Enum.map_join(", ", &"$#{&1}")})
          """,
          Enum.map(@columns, &Map.fetch!(row, &1)) ++ [ReadVersion.current()]
        )
      end

      length(rows)
    end)
  end

  defp delete(source_law, treatments, commences) do
    {sql, args} =
      Enum.reduce(
        [
          {"treatment", treatments && Enum.map(treatments, &to_string/1)},
          {"commences", commences}
        ],
        {"DELETE FROM commencement_rules WHERE source_law = $1", [source_law]},
        &filter/2
      )

    Repo.query!(sql, args)
  end

  defp filter({_column, nil}, acc), do: acc

  defp filter({"treatment", ts}, {sql, args}),
    do: {sql <> " AND treatment = ANY($#{length(args) + 1})", args ++ [ts]}

  defp filter({column, v}, {sql, args}),
    do: {sql <> " AND #{column} = $#{length(args) + 1}", args ++ [v]}

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
