defmodule SertantaiLegal.Scraper.LatRepair do
  @moduledoc """
  Targeted LAT text repair (LAT parser coverage session, 2026-10-07): the
  rows the old list-text bug corrupted are re-parsed from their provision's
  legislation.gov.uk fragment (`section/N`, `regulation/N`), not by
  re-parsing whole laws; only rows whose words change are written
  (`mix lat.repair_text`).

  Handles:
  - `provision/1` — a row id's top-level provision (`s.4`, `reg.2`,
    `art.Article 3`), or `:skip` (schedule, Part, Chapter, heading, table)
  - `provisions/1` — candidate rows → distinct `{law, provision}` + skipped ids
  - `fragment_paths/2` — fragment paths to try, in order (a domestic Order's
    or Rules' `reg.` is an `article`/`rule` on legislation.gov.uk)
  - `in_provision?/3` — is a row the provision or one of its descendants
  - `repairs/2` — `{section_id, old, new}` for held rows whose words change
    (the " … " marker and spacing alone don't count)
  - `causes/1` — each repair's cause, provision-aware: words moved between
    rows of one provision (#174) are a `correction`
  - `only_cause/2` — keep one class of repair (applied in rounds)
  - `cause/2` — a repaired row's lat_changes cause: `correction` when the
    words are the same (reordered/re-spaced: the list-text fix), else
    `unattributed` (an amendment since the last parse, or content the old
    parser dropped — the text alone can't tell)

  Pure.
  """

  alias SertantaiLegal.Scraper.{IdField, LatTextDiff}

  @provision ~r/^(s|reg)\.([0-9]+[A-Z]*)(?=$|[(\[#])/
  @eu_article ~r/^art\.Article ([0-9]+[a-z]*)(?=$|[(\[#])/

  @doc "The top-level provision of a row id, or `{:skip, reason}`."
  @spec provision(String.t()) :: {:ok, String.t()} | {:skip, String.t()}
  def provision(section_id) do
    [_law, local] = String.split(section_id, ":", parts: 2)

    cond do
      m = Regex.run(@provision, local) -> {:ok, "#{Enum.at(m, 1)}.#{Enum.at(m, 2)}"}
      m = Regex.run(@eu_article, local) -> {:ok, "art.Article #{Enum.at(m, 1)}"}
      String.starts_with?(local, "sch.") -> {:skip, "schedule (deferred, #169)"}
      true -> {:skip, "structural row (Part/Chapter/heading/table)"}
    end
  end

  @doc "Distinct `{law, provision}` pairs (sorted) for `{law, section_id}` rows, and the skipped ids."
  @spec provisions([{String.t(), String.t()}]) :: {[{String.t(), String.t()}], [String.t()]}
  def provisions(rows) do
    {ok, skipped} =
      Enum.reduce(rows, {MapSet.new(), []}, fn {law, sid}, {ok, skipped} ->
        case provision(sid) do
          {:ok, p} -> {MapSet.put(ok, {law, p}), skipped}
          {:skip, _} -> {ok, [sid | skipped]}
        end
      end)

    {Enum.sort(ok), Enum.reverse(skipped)}
  end

  @doc "legislation.gov.uk fragment paths (without `/data.xml`) to try for a provision, in order."
  @spec fragment_paths(String.t(), String.t()) :: [String.t()]
  def fragment_paths(law_name, provision) do
    base = "/" <> IdField.normalize_to_slash_format(law_name)

    case String.split(provision, ".", parts: 2) do
      ["s", n] -> ["#{base}/section/#{n}"]
      ["reg", n] -> ["#{base}/regulation/#{n}", "#{base}/article/#{n}", "#{base}/rule/#{n}"]
      ["art", "Article " <> n] -> ["#{base}/article/#{n}"]
    end
  end

  @doc "Whether `section_id` is the provision's row or a descendant (not a sibling like s.40 or s.4A)."
  @spec in_provision?(String.t(), String.t(), String.t()) :: boolean()
  def in_provision?(section_id, law_name, provision) do
    prefix = "#{law_name}:#{provision}"

    case String.split_at(section_id, String.length(prefix)) do
      {^prefix, ""} -> true
      {^prefix, <<c::utf8, _::binary>>} -> c in [?(, ?[, ?#]
      _ -> false
    end
  end

  @doc """
  `{section_id, old, new}` for rows in both `stored` and `fresh`
  (`%{section_id => text}`) whose words differ; ordered by section_id.
  """
  @spec repairs(%{String.t() => String.t() | nil}, %{String.t() => String.t() | nil}) ::
          [{String.t(), String.t() | nil, String.t() | nil}]
  def repairs(stored, fresh) do
    for {sid, new} <- Enum.sort(fresh),
        Map.has_key?(stored, sid),
        old = Map.fetch!(stored, sid),
        words(old) != words(new),
        do: {sid, old, new}
  end

  @doc "The lat_changes cause for a repaired row (see moduledoc)."
  @spec cause(String.t() | nil, String.t() | nil) :: String.t()
  def cause(old, new),
    do: if(LatTextDiff.kind(old, new) == "reordered", do: "correction", else: "unattributed")

  @doc "Repairs whose cause (`causes/1`) is `cause` (nil keeps all) — to apply one class at a time."
  @spec only_cause([{String.t(), String.t() | nil, String.t() | nil}], String.t() | nil) ::
          [{String.t(), String.t() | nil, String.t() | nil}]
  def only_cause(repairs, nil), do: repairs

  def only_cause(repairs, cause) do
    for {sid, old, new, ^cause} <- causes(repairs), do: {sid, old, new}
  end

  @doc """
  `{section_id, old, new, cause}` for each repair. Within a provision, words
  that moved between rows (a section row's stray content going to its
  subsection, #174) are a `correction`: a row whose gained words were lost by
  rows of the same provision, and whose lost words were gained by them.
  Anything else follows `cause/2` (a reorder is a correction; other new
  wording — an amendment, restored content — is `unattributed`).
  """
  @spec causes([{String.t(), String.t() | nil, String.t() | nil}]) ::
          [{String.t(), String.t() | nil, String.t() | nil, String.t()}]
  def causes(repairs) do
    pools =
      repairs
      |> Enum.group_by(&group_key(elem(&1, 0)), fn {_, o, n} -> {bag(o), bag(n)} end)
      |> Map.new(fn {key, bags} ->
        lost = Enum.reduce(bags, %{}, fn {o, n}, acc -> add(acc, minus(o, n)) end)
        gained = Enum.reduce(bags, %{}, fn {o, n}, acc -> add(acc, minus(n, o)) end)
        {key, {lost, gained}}
      end)

    for {sid, old, new} <- repairs do
      {lost_pool, gained_pool} = Map.fetch!(pools, group_key(sid))
      {o, n} = {bag(old), bag(new)}
      gained = minus(n, o)
      lost = minus(o, n)

      moved? =
        (gained != %{} or lost != %{}) and minus(gained, lost_pool) == %{} and
          minus(lost, gained_pool) == %{}

      {sid, old, new, if(moved?, do: "correction", else: cause(old, new))}
    end
  end

  defp group_key(sid) do
    with [_, _] <- String.split(sid, ":", parts: 2),
         {:ok, p} <- provision(sid) do
      p
    else
      _ -> sid
    end
  end

  defp bag(text), do: text |> words() |> String.split() |> Enum.frequencies()

  defp minus(a, b) do
    for {w, c} <- a, d = c - Map.get(b, w, 0), d > 0, into: %{}, do: {w, d}
  end

  defp add(a, b), do: Map.merge(a, b, fn _w, x, y -> x + y end)

  defp words(nil), do: ""
  defp words(text), do: text |> String.replace("…", " ") |> String.split() |> Enum.join(" ")
end
