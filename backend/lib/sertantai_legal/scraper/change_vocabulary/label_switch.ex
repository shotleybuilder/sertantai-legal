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

  `merge_kept/3` and `family_in?/2` are pure; `switched?/1`, `stored/1` and
  `timeline/2` read the database.
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

        Enum.any?(rows, fn [f] -> family_in?(f, fams) end)
    end
  end

  @doc """
  True when `family` is one of `fams` by its exact name, the register's
  display marker (`💙 `) dropped: never a substring, so a setting naming one
  family switches no other.
  """
  @spec family_in?(String.t() | nil, [String.t()]) :: boolean()
  def family_in?(nil, _fams), do: false

  def family_in?(family, fams),
    do: String.replace(family, ~r/^[^[:alnum:]]+/u, "") in fams

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
  `law`'s stored timeline as rows the switch can keep: a switched law's
  known-limit rows keep the label they have (`merge_kept/3`), so its
  refresh never rebuilds the old register for them (Maritime Safety:
  Switch-over, 2026-11-07). Lists the table holds as NULL read as `[]`.
  """
  @spec stored(String.t()) :: [map()]
  def stored(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, valid_from, valid_to, status, in_force_from, changed_by, territory, " <>
          "change_ids, changed_by_all, commenced_by FROM lat_label_timeline WHERE law_name = $1 " <>
          "ORDER BY section_id, valid_from",
        [law]
      )

    for [sid, from, to, status, iff, by, ter, ids, all, cb] <- rows,
        do: %{
          law_name: law,
          section_id: sid,
          valid_from: from,
          valid_to: to,
          status: status,
          in_force_from: iff,
          changed_by: by,
          territory: ter,
          change_ids: ids || [],
          changed_by_all: all || [],
          commenced_by: cb || []
        }
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
