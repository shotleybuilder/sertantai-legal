defmodule SertantaiLegal.Scraper.LabelsToday do
  @moduledoc """
  Each provision's labels as at today (lat-refactor LR-25): its
  `lat_label_timeline` period in force on the UK date, read through the
  `lat_labels_today` view. Served in the LAT pull under the contract's names
  (`status`, `effective_from` = the period's `in_force_from`, `changed_by`);
  a provision with no period today gets nils — unknown, never a default.
  """

  alias SertantaiLegal.Repo

  @type labels :: %{
          status: String.t() | nil,
          effective_from: Date.t() | nil,
          changed_by: String.t() | nil
        }

  @doc "A law's labels as at today, by section_id (DB)."
  @spec for_law(String.t()) :: %{String.t() => labels()}
  def for_law(law_name) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, status, in_force_from, changed_by FROM lat_labels_today WHERE law_name = $1",
        [law_name]
      )

    Map.new(rows, fn [sid, status, from, by] ->
      {sid, %{status: status, effective_from: from, changed_by: by}}
    end)
  end

  @nil_labels %{status: nil, effective_from: nil, changed_by: nil}

  @doc "Each row (a map with `section_id`) with today's labels put on it; nils when it has none."
  @spec put([map()], %{String.t() => labels()}) :: [map()]
  def put(rows, labels),
    do: Enum.map(rows, &Map.merge(&1, Map.get(labels, &1.section_id, @nil_labels)))
end
