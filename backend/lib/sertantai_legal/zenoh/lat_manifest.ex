defmodule SertantaiLegal.Zenoh.LatManifest do
  @moduledoc """
  Payloads for the LAT manifest queryables (fractalatai #62):

      fractalaw/@{tenant}/data/legislation/lat-manifest/{law_name}
      fractalaw/@{tenant}/data/legislation/lat-manifest/*

  Each entry is `{law_name, row_count, lat_hash, updated_at}` (see
  `SertantaiLegal.Scraper.LatHash`). Fractalaw compares `lat_hash` with the
  version it holds and re-pulls only laws that differ. A single law without LAT
  answers `row_count: 0` with the empty hash; `*` lists only laws with LAT, so a
  law absent from it holds none.

  Arrow IPC by default, JSON with `?format=json` — as for the other
  `DataServer` queryables, which delegates here.
  """

  alias SertantaiLegal.Scraper.LatHash.Query

  @doc "Parse the key suffix after `lat-manifest/`."
  @spec target(String.t()) :: :all | {:law, String.t()}
  def target(suffix) when suffix in ["*", "**"], do: :all
  def target(law_name), do: {:law, law_name}

  @doc "Manifest payload for a target in `:json` or `:arrow`."
  @spec fetch(:all | {:law, String.t()}, :json | :arrow) :: {:ok, binary()} | {:error, term()}
  def fetch({:law, law_name}, format), do: encode([Query.for_law(law_name)], format, :one)
  def fetch(:all, format), do: encode(Query.all(), format, :many)

  defp encode([entry], :json, :one), do: {:ok, Jason.encode!(entry)}
  defp encode(entries, :json, :many), do: {:ok, Jason.encode!(entries)}
  defp encode([], :arrow, _), do: {:ok, <<>>}

  defp encode(entries, :arrow, _) do
    %{
      law_name: Enum.map(entries, & &1.law_name),
      row_count: Enum.map(entries, & &1.row_count),
      lat_hash: Enum.map(entries, & &1.lat_hash),
      updated_at: Enum.map(entries, & &1.updated_at)
    }
    |> Explorer.DataFrame.new()
    |> Explorer.DataFrame.dump_ipc_stream()
  end
end
