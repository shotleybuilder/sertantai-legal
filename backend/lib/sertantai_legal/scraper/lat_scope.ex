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
  renumbered. Scopes only widen (`widen/2`); narrowing is explicit
  (`narrowed/3`, `narrow!/3`). Which fragments a large Act keeps:
  `LatScope.Relevance`.

  Pure except `set!/2`, `narrow!/3`, `exclude!/2` and `get/1`.
  """

  alias SertantaiLegal.Repo

  @doc "The data.xml paths to fetch for `slash_path` (e.g. \"ukpga/1991/57\")."
  @spec paths(String.t(), map() | nil) :: [String.t()]
  def paths(slash_path, %{"fragments" => [_ | _] = fragments}),
    do: Enum.map(fragments, &"/#{slash_path}/#{&1}/data.xml")

  # An excluded law holds no LAT: fetch nothing, never the whole body
  def paths(_slash_path, %{"excluded" => true}), do: []
  # A scope with no fragments fetches nothing; only a nil scope is the whole body
  def paths(_slash_path, %{"fragments" => []}), do: []

  def paths(slash_path, _scope), do: ["/#{slash_path}/body/data.xml"]

  @doc """
  The data.xml paths to read for a scoped law: when its body is held
  (`body_held?`), the body — its rows are cut to the scope (`cut/2`), so no
  fragment is fetched beside the whole text (CV-S05 F); else `paths/2`.
  """
  @spec fetch_paths(String.t(), map() | nil, boolean()) :: [String.t()]
  def fetch_paths(slash_path, %{"fragments" => [_ | _]}, true),
    do: ["/#{slash_path}/body/data.xml"]

  def fetch_paths(slash_path, scope, _body_held?), do: paths(slash_path, scope)

  # how deep a row type sits: a fragment's head keeps the deeper rows after
  # it and the nearest shallower ones before it (its Part, Chapter, heading)
  @rank %{
    "part" => 1,
    "chapter" => 2,
    "heading" => 3,
    "section" => 4,
    "article" => 4,
    "sub_section" => 5,
    "sub_article" => 5,
    "paragraph" => 6,
    "sub_paragraph" => 7
  }

  @doc """
  A whole body's rows cut to a scope's fragments: each fragment's head row
  (`section/44` → xml id `section-44`, `part/2/chapter/2` →
  `part-2-chapter-2`), the deeper rows after it up to the next row as
  shallow, and its enclosing rows (Part, Chapter, cross-heading) — as a
  fragment's own parse gives, except that a cross-heading keeps its whole
  parse's id. Positions renumbered. A fragment the body lacks keeps nothing.
  """
  @spec cut([map()], [String.t()]) :: [map()]
  def cut(rows, fragments) do
    rows = Enum.sort_by(rows, & &1.position)
    indexed = Enum.with_index(rows)

    keep =
      for f <- fragments,
          id = String.replace(f, "/", "-"),
          {head, i} <- indexed,
          head[:xml_id] == id,
          r <- fragment_rows(rows, head, i),
          into: MapSet.new(),
          do: r.section_id

    rows
    |> Enum.filter(&MapSet.member?(keep, &1.section_id))
    |> Enum.with_index(1)
    |> Enum.map(fn {r, n} -> %{r | position: n, sort_key: with_position(r.sort_key, n)} end)
  end

  defp fragment_rows(rows, head, i) do
    depth = rank(head)
    below = rows |> Enum.drop(i + 1) |> Enum.take_while(&(rank(&1) > depth))

    {above, _} =
      rows
      |> Enum.take(i)
      |> Enum.reverse()
      |> Enum.reduce({[], depth}, fn r, {acc, shallowest} ->
        if rank(r) in 1..(shallowest - 1)//1,
          do: {[r | acc], rank(r)},
          else: {acc, shallowest}
      end)

    above ++ [head | below]
  end

  # other rows (tables, notes) sit inside a provision; a signature ends
  # every fragment and encloses none
  defp rank(%{section_type: "signed"}), do: 0
  defp rank(%{section_type: t}), do: Map.get(@rank, t, 8)

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
  (NI Orders in Council number articles, not sections). Named schedules give
  no fragment: no schedules in LAT (LR-10).
  """
  @spec fragments_for(map()) :: [String.t()]
  def fragments_for(p) do
    unit =
      if String.starts_with?(Map.get(p, "law", ""), "UK_nisi_"), do: "article", else: "section"

    Enum.map(Map.get(p, "sections", []), &"#{unit}/#{&1}")
  end

  @doc """
  A scope without its schedule fragments (no schedules in LAT, LR-10):
  `{:narrowed, scope}`, `{:excluded, scope}` when only schedules were scoped
  (nothing left to parse), or `:unchanged` (no schedule fragments, or a whole
  law). `entry` is recorded in `history` as for `narrowed/3`.
  """
  @spec without_schedules(map() | nil, map()) ::
          {:narrowed, map()} | {:excluded, map()} | :unchanged
  def without_schedules(%{"fragments" => fragments} = scope, entry) do
    case Enum.reject(fragments, &String.starts_with?(&1, "schedule/")) do
      ^fragments -> :unchanged
      [] -> {:excluded, excluded(scope, entry)}
      rest -> {:narrowed, narrowed(scope, rest, entry)}
    end
  end

  def without_schedules(_scope, _entry), do: :unchanged

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

  @doc """
  Narrow a scope: replace its fragments (an explicit narrow — `widen/2`
  never does). A whole law (nil scope) gets `fragments`; `entry` (`at`,
  `purpose`, `reason`, `set_by`) is appended to `history` with what was
  added, removed, or that the law was whole.
  """
  @spec narrowed(map() | nil, [String.t()], map()) :: map()
  def narrowed(scope, fragments, entry) do
    fragments = Enum.uniq(fragments)

    change =
      case scope do
        nil ->
          %{"narrowed_from" => "whole", "narrowed_to" => fragments}

        %{"fragments" => current} ->
          %{
            "narrowed_to" => fragments,
            "added" => fragments -- current,
            "removed" => current -- fragments
          }
      end

    %{
      "fragments" => fragments,
      "purposes" =>
        Enum.uniq(((scope || %{})["purposes"] || []) ++ [entry["purpose"]])
        |> Enum.reject(&is_nil/1),
      "history" => ((scope || %{})["history"] || []) ++ [Map.merge(entry, change)]
    }
  end

  @doc """
  Exclude a law from LAT (#166: no EHS link, Jason 2026-10-07): a scope
  with no fragments, flagged `excluded`, so no parse path fetches it again.
  `entry` is appended to `history` like `narrowed/3`.
  """
  @spec excluded(map() | nil, map()) :: map()
  def excluded(scope, entry) do
    scope
    |> narrowed([], Map.put(entry, "excluded", true))
    |> Map.put("excluded", true)
  end

  @doc "Whether a scope excludes the law from LAT."
  @spec excluded?(map() | nil) :: boolean()
  def excluded?(%{"excluded" => true}), do: true
  # nothing to parse: a scope with no fragments (only nil is the whole law)
  def excluded?(%{"fragments" => []}), do: true
  def excluded?(_scope), do: false

  @doc """
  Mark a law excluded (`opts`: `:reason`, `:set_by`). The caller archives and
  discards its LAT (`LatArchive.discard/3`, which records the `discarded`
  lat_event). Returns the new scope.
  """
  @spec exclude!(String.t(), keyword()) :: map()
  def exclude!(law_name, opts) do
    entry = %{
      "at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "purpose" => "relevance",
      "reason" => Keyword.get(opts, :reason),
      "set_by" => Keyword.get(opts, :set_by)
    }

    new_scope = excluded(get(law_name), entry)

    Repo.query!(
      "UPDATE legal_register SET lat_scope = $2 WHERE country = 'uk' AND name = $1",
      [law_name, new_scope]
    )

    new_scope
  end

  @doc """
  Narrow a law's stored scope to `fragments` (`opts`: `:purpose`, `:reason`,
  `:set_by`). Unlike `set!/2` this may narrow a whole law holding LAT; the
  caller archives the LAT first and re-parses after (`mix lat.scope
  --relevance`). Returns the new scope.
  """
  @spec narrow!(String.t(), [String.t()], keyword()) :: map()
  def narrow!(law_name, [_ | _] = fragments, opts) do
    entry = %{
      "at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "purpose" => Keyword.get(opts, :purpose, "relevance"),
      "reason" => Keyword.get(opts, :reason),
      "set_by" => Keyword.get(opts, :set_by)
    }

    new_scope = narrowed(get(law_name), fragments, entry)

    Repo.query!(
      "UPDATE legal_register SET lat_scope = $2 WHERE country = 'uk' AND name = $1",
      [law_name, new_scope]
    )

    new_scope
  end

  # The sort key without its position segment (the last dot segment before "~")
  defp structural(key), do: Regex.replace(~r/\.\d+(~.*)$/, key, "\\1")

  defp with_position(key, n),
    do: Regex.replace(~r/\.\d+(~.*)$/, key, "." <> String.pad_leading("#{n}", 6, "0") <> "\\1")
end
