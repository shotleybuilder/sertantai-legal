defmodule SertantaiLegal.Scraper.Amendment.Store do
  @moduledoc """
  The amendment ruleset's table, `amendment_rules` (amendment-rules AR-01):
  a source document's rules are written together (delete + insert by
  `source_law`, or by source and amended law for a re-read:
  `write_changed/3`), so they always match its latest reading; a law's rules are
  read back as `Rule` structs. DB only — the rules themselves are
  `Amendment.Rule`.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Amendment.Rule

  @columns ~w(amends targets operation level source_law source_ref source_text treatment saved)a

  @doc "Replace the rules read from `source_law` with `rules`. Returns `{:ok, count}`."
  @spec write(String.t(), [Rule.t()]) :: {:ok, non_neg_integer()}
  def write(source_law, rules) do
    for r <- rules, r.source.law != source_law do
      raise ArgumentError, "rule from #{r.source.law} written as #{source_law}'s"
    end

    rows = Enum.map(rules, &Rule.to_row/1)

    Repo.transaction(fn ->
      Repo.query!("DELETE FROM amendment_rules WHERE source_law = $1", [source_law])

      Enum.each(rows, &insert/1)

      length(rows)
    end)
  end

  @doc """
  Write only the amended laws whose rules differ from `stored` (the
  source's rules as stored, read before): each such law's rules from
  `source_law` are replaced, and an amended law whose rules are the same
  keeps them and their `read_at`, so no build reading it goes stale
  (`Store.Inputs`; the Amending-law reader stamps session, 2026-11-26: the
  whole source was rewritten when any law's rules differed). Returns
  `{:ok, count, :written | :unchanged}`. A full read pass after a reader
  change finds most laws' rules unchanged (run time 2026-10-26).
  """
  @spec write_changed(String.t(), [Rule.t()], [Rule.t()]) ::
          {:ok, non_neg_integer(), :written | :unchanged}
  def write_changed(source_law, rules, stored) do
    new = Enum.group_by(rules, & &1.amends)
    old = Enum.group_by(stored, & &1.amends)

    changed =
      for law <- Enum.uniq(Map.keys(new) ++ Map.keys(old)),
          rows(Map.get(new, law, [])) != rows(Map.get(old, law, [])),
          do: law

    if changed != [], do: replace(source_law, changed, new)
    {:ok, length(rules), if(changed == [], do: :unchanged, else: :written)}
  end

  defp rows(rules), do: Enum.frequencies(Enum.map(rules, &Rule.to_row/1))

  # `source_law`'s rules for each law in `laws`, replaced by `new`'s
  defp replace(source_law, laws, new) do
    for law <- laws, r <- Map.get(new, law, []), r.source.law != source_law do
      raise ArgumentError, "rule from #{r.source.law} written as #{source_law}'s"
    end

    Repo.transaction(fn ->
      Repo.query!("DELETE FROM amendment_rules WHERE source_law = $1 AND amends = ANY($2)", [
        source_law,
        laws
      ])

      for law <- laws, r <- Map.get(new, law, []), do: insert(Rule.to_row(r))
    end)
  end

  defp insert(row) do
    Repo.query!(
      """
      INSERT INTO amendment_rules (#{Enum.join(@columns, ", ")})
      VALUES (#{1..length(@columns) |> Enum.map_join(", ", &"$#{&1}")})
      """,
      Enum.map(@columns, &Map.fetch!(row, &1))
    )
  end

  @doc "The rules amending `law_name`, from every source."
  @spec for_law(String.t()) :: [Rule.t()]
  def for_law(law_name), do: select("amends", law_name)

  @doc "The rules read from the amending law `source_law`."
  @spec for_source(String.t()) :: [Rule.t()]
  def for_source(source_law), do: select("source_law", source_law)

  defp select(column, value) when column in ["amends", "source_law"] do
    %{rows: rows, columns: cols} =
      Repo.query!(
        """
        SELECT #{Enum.join(@columns, ", ")} FROM amendment_rules
        WHERE #{column} = $1 ORDER BY source_law, source_ref, read_at
        """,
        [value]
      )

    for r <- rows do
      cols |> Enum.map(&String.to_existing_atom/1) |> Enum.zip(r) |> Map.new() |> Rule.from_row()
    end
  end
end
