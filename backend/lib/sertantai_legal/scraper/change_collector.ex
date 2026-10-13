defmodule SertantaiLegal.Scraper.ChangeCollector do
  @moduledoc """
  Fills the change register `lat_change_log` (lat-refactor LR-22/LR-23) for
  a law, offline from the CLML store: parse (store only) → the collectors →
  delete + insert that law's records per collector, in one transaction.

  Collectors: `Feed` (changes-feed effects with their joins), `Markup`
  (change markup no effect explains). Never fetches.
  Thin: the joins and records are the pure collectors'.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeCollector.{Feed, Markup, Record}
  alias SertantaiLegal.Scraper.LatStagedParser

  @doc "A law's records from the store, by collector."
  @spec collect(String.t()) :: {:ok, %{String.t() => [Record.t()]}} | {:error, term()}
  def collect(law_name) do
    with {:ok, %{rows: rows, notes: notes, effects: effects}} <-
           LatStagedParser.fetch_changes(law_name, store: :only) do
      {:ok,
       %{
         "feed" => Feed.records(law_name, rows, notes, effects),
         "markup" => Markup.records(law_name, rows)
       }}
    end
  end

  @doc "Replace a law's records for each collector given. Returns rows written."
  @spec write(String.t(), %{String.t() => [Record.t()]}) :: {:ok, non_neg_integer()}
  def write(law_name, by_collector) do
    Repo.transaction(fn ->
      Enum.reduce(by_collector, 0, fn {collector, records}, n ->
        Repo.query!("DELETE FROM lat_change_log WHERE law_name = $1 AND collector = $2", [
          law_name,
          collector
        ])

        now = DateTime.utc_now()

        records
        |> Enum.map(&row(&1, collector, now))
        |> Enum.chunk_every(2000)
        |> Enum.reduce(n, fn chunk, acc ->
          {k, _} = Repo.insert_all("lat_change_log", chunk)
          acc + k
        end)
      end)
    end)
  end

  defp row(%Record{} = r, collector, now) do
    r
    |> Map.from_struct()
    |> Map.update!(:in_force, fn entries -> Enum.map(entries, &Map.new/1) end)
    |> Map.merge(%{id: Ecto.UUID.bingenerate(), collector: collector, collected_at: now})
  end
end
