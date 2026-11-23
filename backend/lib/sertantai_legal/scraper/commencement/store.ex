defmodule SertantaiLegal.Scraper.Commencement.Store do
  @moduledoc """
  The commencement ruleset's table, `commencement_rules` (CR-01): a source
  document's rules are written together (delete + insert by `source_law`),
  so they always match its latest reading, and only when they changed (an
  identical reading moves only the reader stamp); a law's rules are read back as
  `Rule` structs. Each row is stamped with the reader code that read it,
  its own read path's (`Commencement.ReadVersion`, #193). DB only — the rules themselves are
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
    {:ok, n, _} = write_changed(source_law, rules, opts)
    {:ok, n}
  end

  @doc """
  `write/3`, saying whether the rules were written or found unchanged:
  `{:ok, count, :written | :unchanged}`. Rules identical to those stored in
  the write's scope (the same rules, any order) are not re-written: only
  their reader stamp moves, and `read_at` stays, so no build that read them
  goes stale (`Store.Inputs`: `max(read_at)`). A re-read after a reader
  change finds most sources' rules unchanged (`Amendment.Store.write_changed/3`).
  """
  @spec write_changed(String.t(), [Rule.t()], keyword()) ::
          {:ok, non_neg_integer(), :written | :unchanged}
  def write_changed(source_law, rules, opts \\ []) do
    for r <- rules, r.source.law != source_law do
      raise ArgumentError, "rule from #{r.source.law} written as #{source_law}'s"
    end

    scope = {Keyword.get(opts, :treatments), Keyword.get(opts, :commences)}

    {:ok, {n, how}} =
      Repo.transaction(fn ->
        if same?(stored(source_law, scope), rules) do
          restamp(source_law, scope)
          {length(rules), :unchanged}
        else
          {replace(source_law, rules, scope), :written}
        end
      end)

    {:ok, n, how}
  end

  defp same?(stored, rules), do: Enum.frequencies(stored) == Enum.frequencies(rules)

  defp replace(source_law, rules, {treatments, commences}) do
    delete(source_law, treatments, commences)

    for row <- Enum.map(rules, &Rule.to_row/1) do
      Repo.query!(
        """
        INSERT INTO commencement_rules (#{Enum.join(@columns, ", ")}, reader_version)
        VALUES (#{1..(length(@columns) + 1) |> Enum.map_join(", ", &"$#{&1}")})
        """,
        Enum.map(@columns, &Map.fetch!(row, &1)) ++ [ReadVersion.for_treatment(row.treatment)]
      )
    end

    length(rules)
  end

  defp stored(source_law, {treatments, commences}) do
    {where, args} = scoped(source_law, treatments, commences)

    %{rows: rows, columns: cols} =
      Repo.query!("SELECT #{Enum.join(@columns, ", ")} FROM commencement_rules" <> where, args)

    from_rows(rows, cols)
  end

  defp restamp(source_law, {treatments, commences}) do
    {where, args} = scoped(source_law, treatments, commences)

    {stamp, params} = current_stamp(length(args) + 1)

    Repo.query!(
      "UPDATE commencement_rules SET reader_version = #{stamp}" <> where,
      args ++ params
    )
  end

  @doc """
  SQL true for a rule read by other code than its read path's now
  (`ReadVersion`), or before the code was recorded: `{condition, params}`,
  its parameters numbered from `$n`. For the build's staleness
  (`Store.Inputs`) and the re-read (`StepProcedures.RereadStale`).
  """
  @spec stale_condition(pos_integer()) :: {String.t(), list()}
  def stale_condition(n) do
    {stamp, params} = current_stamp(n)
    {"reader_version IS DISTINCT FROM #{stamp}", params}
  end

  # each row's read path's version now, by its treatment
  defp current_stamp(n) do
    {"(CASE WHEN treatment = ANY($#{n}) THEN $#{n + 1} WHEN treatment = ANY($#{n + 2}) " <>
       "THEN $#{n + 3} ELSE $#{n + 4} END)",
     [
       ReadVersion.treatments(:orders),
       ReadVersion.current(:orders),
       ReadVersion.treatments(:effects),
       ReadVersion.current(:effects),
       ReadVersion.current(:clause)
     ]}
  end

  defp from_rows(rows, cols) do
    for r <- rows do
      cols |> Enum.map(&String.to_existing_atom/1) |> Enum.zip(r) |> Map.new() |> Rule.from_row()
    end
  end

  defp delete(source_law, treatments, commences) do
    {where, args} = scoped(source_law, treatments, commences)
    Repo.query!("DELETE FROM commencement_rules" <> where, args)
  end

  # the write's scope: the source, and its treatments and law commenced if named
  defp scoped(source_law, treatments, commences) do
    Enum.reduce(
      [
        {"treatment", treatments && Enum.map(treatments, &to_string/1)},
        {"commences", commences}
      ],
      {" WHERE source_law = $1", [source_law]},
      &filter/2
    )
  end

  defp filter({_column, nil}, acc), do: acc

  defp filter({"treatment", ts}, {sql, args}),
    do: {sql <> " AND treatment = ANY($#{length(args) + 1})", args ++ [ts]}

  defp filter({column, v}, {sql, args}),
    do: {sql <> " AND #{column} = $#{length(args) + 1}", args ++ [v]}

  @order_treatments ~w(order_date order_schedule)

  @doc """
  The orders whose rules for `law_name` are stored (never the law itself):
  what a re-read reads again, in or out of the law's order list.
  """
  @spec order_sources(String.t()) :: [String.t()]
  def order_sources(law_name) do
    Repo.query!(
      """
      SELECT DISTINCT source_law FROM commencement_rules
      WHERE commences = $1 AND source_law <> $1 AND treatment = ANY($2) ORDER BY 1
      """,
      [law_name, @order_treatments]
    ).rows
    |> List.flatten()
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

    from_rows(rows, cols)
  end
end
