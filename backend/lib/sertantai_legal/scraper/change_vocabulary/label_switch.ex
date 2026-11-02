defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelSwitch do
  @moduledoc """
  Which laws are labelled by the change vocabulary, and their timeline
  (CV-06, Jason 2026-10-31: "OH&S only, by family"). One setting lists the
  switched families (`config :sertantai_legal, :label_families`); a law in
  one has its `lat_label_timeline` from its merged changes
  (`LabelSource.timeline/1`), every other law keeps the change register's
  (`LabelTimeline.build/2`) until its family passes steps 1–11.

  The named known limits (`KnownLimits`: missing repeals, date gaps) keep
  their old label (Jason 2026-11-02). Nothing is written when the table's
  rules break (`LabelPeriods.violations/1`).

  `merge_kept/3` is pure; `switched?/1` and `timeline/2` read the database.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.{KnownLimits, LabelPeriods, LabelSource}

  @doc "The switched families (the setting)."
  @spec families() :: [String.t()]
  def families, do: Application.get_env(:sertantai_legal, :label_families, [])

  @doc "True when `law` is in a switched family."
  @spec switched?(String.t()) :: boolean()
  def switched?(law) do
    case families() do
      [] ->
        false

      fams ->
        %{rows: rows} =
          Repo.query!("SELECT family FROM uk_lrt WHERE name = $1 AND family IS NOT NULL", [law])

        Enum.any?(rows, fn [f] -> Enum.any?(fams, &String.contains?(f, &1)) end)
    end
  end

  @doc """
  A switched law's timeline: its merged changes' periods, a known limit's
  old ones (`old`: the register's periods, structs or maps) in their place;
  `{:error, {:violations, list}}` when the table's rules break.
  """
  @spec timeline(String.t(), [map()]) :: {:ok, [map()]} | {:error, term()}
  def timeline(law, old) do
    with {:ok, new} <- LabelSource.timeline(law),
         rows = merge_kept(new, old, KnownLimits.sids()),
         [] <- LabelPeriods.violations(rows) do
      {:ok, rows}
    else
      [_ | _] = violations -> {:error, {:violations, violations}}
      {:error, _} = error -> error
    end
  end

  @doc """
  The new periods with each `kept` row's old periods in their place (an old
  period as a timeline row: no `changed_by_all` / `commenced_by`).
  """
  @spec merge_kept([map()], [map()], MapSet.t(String.t())) :: [map()]
  def merge_kept(new, old, kept) do
    old_kept =
      for p <- old,
          p = if(is_struct(p), do: Map.from_struct(p), else: p),
          MapSet.member?(kept, p.section_id),
          do: Map.merge(%{changed_by_all: [], commenced_by: []}, p)

    Enum.reject(new, &MapSet.member?(kept, &1.section_id)) ++ old_kept
  end
end
