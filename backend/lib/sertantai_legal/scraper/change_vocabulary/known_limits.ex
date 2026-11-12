defmodule SertantaiLegal.Scraper.ChangeVocabulary.KnownLimits do
  @moduledoc """
  The rows the switch-over names as known limits whose label the new method
  doesn't yet give (CV-06): the 39 rows whose repeal no table read holds
  (CV-06a, `cv-06a-known-limits.md`) and the rows whose change no source
  dates (`cv-06-date-gaps.md`, Jason 2026-11-01: "Named gap"); and Maritime
  Safety's rule breaches below the triage size (`switch-over/maritime-safety-known-limits.md`,
  2026-11-07), and Environmental Protection's
  (`switch-over/environmental-protection-known-limits.md`, 2026-11-12). The rules
  check lists them apart; the writer keeps their old label (Jason
  2026-11-02). Each file is a markdown table, a row's section_id first.

  Reads the two files; writes nothing.
  """

  @files ~w(
    data/reports/change-vocabulary/cv-06a-known-limits.md
    data/reports/change-vocabulary/cv-06-date-gaps.md
    data/reports/switch-over/maritime-safety-known-limits.md
    data/reports/switch-over/environmental-protection-known-limits.md
  )

  @doc "The files listing them."
  @spec files() :: [String.t()]
  def files, do: @files

  @doc "Their section_ids."
  @spec sids() :: MapSet.t(String.t())
  def sids do
    for file <- @files,
        {:ok, text} <- [File.read(file)],
        sid <- parse(text),
        into: MapSet.new(),
        do: sid
  end

  @doc "The section_ids a known-limits table lists (its rows' first cell)."
  @spec parse(String.t()) :: [String.t()]
  def parse(text),
    do: for([_, sid] <- Regex.scan(~r/^\| (UK_[^ |]+) \|/m, text), do: sid)
end
