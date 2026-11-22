defmodule SertantaiLegal.Scraper.Commencement.FeedErrors do
  @moduledoc """
  The register of proven feed errors (Decision 12, Jason 2026-11-22): rows
  whose feed record the law's own text proves wrong, each entered with the
  feed's record as stored, what it gets wrong, the proof (the law, its
  provision and its words), our reading, and who decided it, when and
  where. Held in `test/fixtures/commencement_check/feed_errors.json`, keyed
  "<law> <provision>", written only through the accept path (dry run,
  Jason, write).

  The feed gate counts a registered row apart (`:feed_error`), never as
  agreeing; an entry whose row is gone, whose feed record changed (look
  again: legislation.gov.uk may have corrected it) or whose reading of
  ours changed is stale, and fails the gate. Pure.
  """

  @type register :: %{String.t() => map()}
  @type stale :: {String.t(), :row_gone | :feed_changed | :ours_changed | :invalid}

  @wrong ~w(date place no_record)

  @doc """
  The rows with each registered one marked `:feed_error` (its entry under
  `:feed_error`), and the stale entries among the `laws` run.
  """
  @spec mark([map()], register(), [String.t()]) :: {[map()], [stale()]}
  def mark(rows, register, laws) do
    by_key = Map.new(rows, &{key(&1), &1})
    run = MapSet.new(laws)

    stale =
      for {k, e} <- Enum.sort(register),
          MapSet.member?(run, law_of(k)),
          why = staleness(by_key[k], e),
          why != nil,
          do: {k, why}

    gone = MapSet.new(stale, &elem(&1, 0))

    marked = Enum.map(rows, &marked(&1, register, gone))

    {marked, stale}
  end

  @doc "A proposal (wrong, proof, decided, feed_by) with the row's feed record and our reading filled in."
  @spec entry(map(), map()) :: map()
  def entry(proposal, row),
    do:
      Map.merge(proposal, %{
        "feed" => pair(row.feed),
        "ours" => pair({row.partial_from, row.full_from})
      })

  @doc "`:ok` for an entry with its record, a known wrong, its proof and its decision; else why not."
  @spec validate(map()) :: :ok | {:error, String.t()}
  def validate(e) do
    cond do
      not match?([_, _], e["feed"]) or not match?([_, _], e["ours"]) ->
        {:error, "feed or ours missing"}

      e["wrong"] not in @wrong ->
        {:error, "wrong must be one of #{Enum.join(@wrong, ", ")}"}

      not filled?(e["proof"], ~w(law provision words)) ->
        {:error, "proof incomplete"}

      not filled?(e["decided"], ~w(by on session decision)) ->
        {:error, "decision incomplete"}

      true ->
        :ok
    end
  end

  @doc "The register's entries that fail `validate/1`, as stale (`:invalid`)."
  @spec invalid(register()) :: [{String.t(), :invalid}]
  def invalid(register),
    do: for({k, e} <- Enum.sort(register), validate(e) != :ok, do: {k, :invalid})

  @doc "A row's register key."
  @spec key(map()) :: String.t()
  def key(%{law: law, id: id}), do: "#{law} #{id}"

  defp marked(row, register, gone) do
    k = key(row)

    case {register[k], k in gone} do
      {%{} = e, false} -> row |> Map.put(:yardstick, :feed_error) |> Map.put(:feed_error, e)
      _ -> row
    end
  end

  defp law_of(key), do: key |> String.split(" ", parts: 2) |> hd()

  defp staleness(nil, _e), do: :row_gone

  defp staleness(row, e) do
    cond do
      pair(row.feed) != e["feed"] -> :feed_changed
      pair({row.partial_from, row.full_from}) != e["ours"] -> :ours_changed
      true -> nil
    end
  end

  defp pair(nil), do: [nil, nil]
  defp pair({a, b}), do: [iso(a), iso(b)]

  defp iso(nil), do: nil
  defp iso(%Date{} = d), do: Date.to_iso8601(d)

  defp filled?(%{} = m, keys), do: Enum.all?(keys, &(is_binary(m[&1]) and m[&1] != ""))
  defp filled?(_m, _keys), do: false
end
