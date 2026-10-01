defmodule SertantaiLegal.Scraper.LatStatus.Apply do
  @moduledoc """
  Writes per-row LAT status (#167, L8.1) for a law: loads its rows and
  amendment notes, resolves with the pure `LatStatus`, and updates only the
  rows whose status changes.

  Called after a LAT parse's notes are persisted (`LatStagedParser`) and by
  `mix lat.status` (backfill / recompute).
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatStatus

  require Logger

  @type result :: %{
          law_name: String.t(),
          rows: non_neg_integer(),
          changed: non_neg_integer(),
          transitions: %{{String.t() | nil, String.t()} => pos_integer()}
        }

  @doc """
  Recompute the law's statuses. Options: `dry_run: true` resolves and reports
  without writing.
  """
  @spec refresh(String.t(), keyword()) :: result()
  def refresh(law_name, opts \\ []) when is_binary(law_name) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, text, status FROM legal_articles WHERE law_name = $1",
        [law_name],
        timeout: :infinity
      )

    %{rows: notes} =
      Repo.query!(
        "SELECT affected_sections, text, code_type FROM amendment_annotations WHERE law_name = $1",
        [law_name],
        timeout: :infinity
      )

    current = Map.new(rows, fn [sid, _text, status] -> {sid, status} end)

    resolved =
      LatStatus.resolve(
        Enum.map(rows, fn [sid, text, status] ->
          %{section_id: sid, text: text, status: status}
        end),
        Enum.map(notes, fn [sections, text, code_type] ->
          %{affected_sections: sections, text: text || "", code_type: code_type}
        end)
      )

    changes = for {sid, status} <- resolved, current[sid] != status, do: {sid, status}

    unless opts[:dry_run], do: write!(changes)

    %{
      law_name: law_name,
      rows: length(rows),
      changed: length(changes),
      transitions: Enum.frequencies_by(changes, fn {sid, status} -> {current[sid], status} end)
    }
  end

  @doc "Refresh after a parse; a failure is logged and never fails the parse."
  @spec refresh_after_parse(String.t()) :: :ok
  def refresh_after_parse(law_name) do
    %{changed: changed} = refresh(law_name)
    Logger.info("[LatStatus] #{law_name}: #{changed} status rows set from notes")
    :ok
  rescue
    e ->
      Logger.warning("[LatStatus] refresh failed for #{law_name}: #{Exception.message(e)}")
      :ok
  end

  defp write!([]), do: :ok

  defp write!(changes) do
    {ids, statuses} = Enum.unzip(changes)

    Repo.query!(
      """
      UPDATE legal_articles AS a SET status = c.status
      FROM unnest($1::text[], $2::text[]) AS c(section_id, status)
      WHERE a.section_id = c.section_id
      """,
      [ids, statuses],
      timeout: :infinity
    )

    :ok
  end
end
