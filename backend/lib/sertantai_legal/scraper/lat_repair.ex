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

  Pure.
  """

  alias SertantaiLegal.Scraper.IdField

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

  defp words(nil), do: ""
  defp words(text), do: text |> String.replace("…", " ") |> String.split() |> Enum.join(" ")
end
