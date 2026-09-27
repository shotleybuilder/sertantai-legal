defmodule SertantaiLegal.Legal.LatEvent.Provenance do
  @moduledoc """
  Pure parsing of fractalaw's enrichment `provenance` (agreed spec,
  2026-09-27) into `enriched` lat_event attributes.

  Fractalaw sends one additive `provenance` column in the law-level taxa
  payload: a JSON list of per-family entries
  (`triage | taxa | fitness | significance`), each with `enrichment_run_id`,
  `run_started_at`, `fractalaw_version`, `enriched_against`
  `{lat_hash, struct_hash}`, `stages` and `provision_method_counts`.

  Until fractalaw ships it (the column is absent), a publish yields one entry
  asserting nothing: no family, run or hashes — legal does not guess what
  fractalaw read. Unparseable provenance is kept under `"raw"`.
  """

  @type entry :: %{
          family: String.t() | nil,
          enrichment_run_id: String.t() | nil,
          enrichment_version: String.t() | nil,
          lat_hash: String.t() | nil,
          struct_hash: String.t() | nil,
          provenance: map() | nil
        }

  @blank %{
    family: nil,
    enrichment_run_id: nil,
    enrichment_version: nil,
    lat_hash: nil,
    struct_hash: nil,
    provenance: nil
  }

  @detail_keys ~w(run_started_at stages provision_method_counts)

  @doc "Per-family event attributes from the payload's `provenance` value."
  @spec entries(String.t() | list() | nil) :: [entry()]
  def entries(nil), do: [@blank]
  def entries(""), do: [@blank]

  def entries(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, list} when is_list(list) and list != [] -> entries(list)
      _ -> [%{@blank | provenance: %{"raw" => json}}]
    end
  end

  def entries(list) when is_list(list) do
    Enum.map(list, fn e ->
      against = Map.get(e, "enriched_against") || %{}

      %{
        family: e["family"],
        enrichment_run_id: e["enrichment_run_id"],
        enrichment_version: e["fractalaw_version"],
        lat_hash: against["lat_hash"],
        struct_hash: against["struct_hash"],
        provenance: e |> Map.take(@detail_keys) |> nil_if_empty()
      }
    end)
  end

  defp nil_if_empty(map) when map_size(map) == 0, do: nil
  defp nil_if_empty(map), do: map
end
