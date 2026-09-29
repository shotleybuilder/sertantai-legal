defmodule SertantaiLegal.Scraper.LatScope do
  @moduledoc """
  Scoped LAT parsing (#166): a law's `lat_scope` lists the legislation.gov.uk
  fragments its LAT holds (`section/82`, `part/15/chapter/5`, `schedule/3`);
  nil means the whole body.

  Two purposes so far:

  - `relevance` — only the relevant part of a large Act (Companies Act 2006
    Part 15 Ch. 5);
  - `enabling_extent` — for a non-Making parent Act, only the sections its
    SIs are made under: their inherited extent_code is the evidence for
    `EnactedBy.EnablingExtent` (the lean-LAT exception: small, kept as
    evidence rather than cached off the DB).

  A fragment's `data.xml` carries its enclosing Part/Chapter (with their
  RestrictExtent), and `LatParser` gives it the same section ids as a full
  parse; only document positions differ. `merge/1` joins fragments: shared
  structural rows once, document order by structural sort key, positions
  renumbered. Scopes only widen (`widen/2`); narrowing is explicit.

  Pure except `set!/2` and `get/1`.
  """

  alias SertantaiLegal.Repo

  @doc "The data.xml paths to fetch for `slash_path` (e.g. \"ukpga/1991/57\")."
  @spec paths(String.t(), map() | nil) :: [String.t()]
  def paths(slash_path, %{"fragments" => [_ | _] = fragments}),
    do: Enum.map(fragments, &"/#{slash_path}/#{&1}/data.xml")

  def paths(slash_path, _scope), do: ["/#{slash_path}/body/data.xml"]

  @doc """
  Join per-document LAT rows into one law's rows. One document is returned
  as is; several (fragments) are deduplicated by section_id, ordered by the
  structural part of the sort key and renumbered (position and the sort
  key's position segment).
  """
  @spec merge([[map()]]) :: [map()]
  def merge([rows]), do: rows

  def merge(row_lists) do
    row_lists
    |> Enum.with_index()
    |> Enum.flat_map(fn {rows, i} ->
      Enum.map(rows, &{structural(&1.sort_key), i, &1.position, &1})
    end)
    |> Enum.sort_by(fn {s, i, p, _} -> {s, i, p} end)
    |> Enum.uniq_by(fn {_, _, _, r} -> r.section_id end)
    |> Enum.with_index(1)
    |> Enum.map(fn {{_, _, _, r}, n} ->
      %{r | position: n, sort_key: with_position(r.sort_key, n)}
    end)
  end

  @doc """
  Widen a scope by `fragments`: `{:ok, new_fragments}`, `:unchanged`, or
  `:whole` (an unscoped law is already whole — never narrowed here).
  """
  @spec widen(map() | nil, [String.t()]) :: {:ok, [String.t()]} | :unchanged | :whole
  def widen(nil, _fragments), do: :whole

  def widen(%{"fragments" => current}, fragments) do
    new = Enum.uniq(current ++ fragments)
    if new == current, do: :unchanged, else: {:ok, new}
  end

  @doc """
  Fragments for an enabling provision `%{\"law\", \"sections\", \"schedules\"}`
  (NI Orders in Council number articles, not sections).
  """
  @spec fragments_for(map()) :: [String.t()]
  def fragments_for(p) do
    unit =
      if String.starts_with?(Map.get(p, "law", ""), "UK_nisi_"), do: "article", else: "section"

    Enum.map(Map.get(p, "sections", []), &"#{unit}/#{&1}") ++
      Enum.map(Map.get(p, "schedules", []), &"schedule/#{&1}")
  end

  @doc "A law's stored scope (nil = whole)."
  @spec get(String.t()) :: map() | nil
  def get(law_name) do
    case Repo.query!("SELECT lat_scope FROM legal_register WHERE name = $1 LIMIT 1", [law_name]) do
      %{rows: [[scope]]} -> scope
      _ -> nil
    end
  end

  @doc """
  Set or widen a law's scope. `opts`: `:fragments`, `:purpose`, `:reason`,
  `:set_by`, and `:create` (true to scope a law that has no scope and no LAT
  — an unscoped law holding LAT is whole and is not narrowed). Each change is
  appended to the scope's `history`. Returns the new scope, or
  `{:unchanged | :whole, scope}`.
  """
  @spec set!(String.t(), keyword()) :: map() | {:unchanged | :whole, map() | nil}
  def set!(law_name, opts) do
    fragments = Keyword.fetch!(opts, :fragments)

    %{rows: [[scope, lat_count]]} =
      Repo.query!(
        "SELECT lat_scope, coalesce(lat_count, 0) FROM legal_register WHERE country = 'uk' AND name = $1",
        [law_name]
      )

    result =
      cond do
        scope != nil -> widen(scope, fragments)
        Keyword.get(opts, :create, false) and lat_count == 0 -> {:ok, Enum.uniq(fragments)}
        true -> :whole
      end

    case result do
      {:ok, new} ->
        entry = %{
          "at" => DateTime.utc_now() |> DateTime.to_iso8601(),
          "added" => new -- ((scope || %{})["fragments"] || []),
          "purpose" => Keyword.get(opts, :purpose),
          "reason" => Keyword.get(opts, :reason),
          "set_by" => Keyword.get(opts, :set_by)
        }

        new_scope = %{
          "fragments" => new,
          "purposes" =>
            Enum.uniq(((scope || %{})["purposes"] || []) ++ [Keyword.get(opts, :purpose)])
            |> Enum.reject(&is_nil/1),
          "history" => ((scope || %{})["history"] || []) ++ [entry]
        }

        Repo.query!(
          "UPDATE legal_register SET lat_scope = $2 WHERE country = 'uk' AND name = $1",
          [law_name, new_scope]
        )

        new_scope

      other ->
        {other, scope}
    end
  end

  # The sort key without its position segment (the last dot segment before "~")
  defp structural(key), do: Regex.replace(~r/\.\d+(~.*)$/, key, "\\1")

  defp with_position(key, n),
    do: Regex.replace(~r/\.\d+(~.*)$/, key, "." <> String.pad_leading("#{n}", 6, "0") <> "\\1")
end
