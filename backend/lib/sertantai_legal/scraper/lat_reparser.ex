defmodule SertantaiLegal.Scraper.LatReparser do
  @moduledoc """
  Standalone LAT + Commentary re-parse for a single law.

  Fetches body XML from legislation.gov.uk, runs LatParser + CommentaryParser,
  and persists the results (DELETE+INSERT).

  Reusable by both StagedParser (taxa sub-stage) and LatAdminController.
  """

  alias SertantaiLegal.Scraper.{LatParser, LatPersister, CommentaryParser, CommentaryPersister}
  alias SertantaiLegal.Scraper.LegislationGovUk.Client
  alias SertantaiLegal.Scraper.IdField
  alias SertantaiLegal.Repo

  require Logger

  @spec reparse(String.t()) :: {:ok, map()} | {:error, String.t()}
  def reparse(law_name) when is_binary(law_name) do
    start = System.monotonic_time(:millisecond)

    with {:ok, {type_code, slash_path}} <- parse_law_name(law_name),
         {:ok, law_id} <- lookup_law_id(law_name),
         {:ok, body_xml} <- fetch_body_xml(slash_path),
         lat_rows <- LatParser.parse(body_xml, %{law_name: law_name, type_code: type_code}),
         {:ok, lat_result} <- LatPersister.persist(lat_rows, law_name, law_id) do
      # Commentary stage
      ref_to_sections = CommentaryParser.build_ref_to_sections(lat_rows)
      annotations = CommentaryParser.parse(body_xml, %{law_name: law_name}, ref_to_sections)

      annotation_result =
        case CommentaryPersister.persist(annotations, law_name, law_id) do
          {:ok, result} -> result
          {:error, _} -> %{inserted: 0}
        end

      duration_ms = System.monotonic_time(:millisecond) - start

      {:ok,
       %{
         lat: lat_result,
         annotations: annotation_result,
         duration_ms: duration_ms
       }}
    end
  end

  # Parse law_name to extract type_code and slash path for API calls.
  # UK_ukpga_1974_37 → {"ukpga", "ukpga/1974/37"}
  defp parse_law_name(law_name) do
    slash_path = IdField.normalize_to_slash_format(law_name)

    case String.split(slash_path, "/") do
      [type_code, _year, _number] ->
        {:ok, {type_code, slash_path}}

      _ ->
        {:error, "Invalid law_name format: #{law_name}"}
    end
  end

  defp lookup_law_id(law_name) do
    case Repo.query("SELECT id::text FROM uk_lrt WHERE name = $1 LIMIT 1", [law_name]) do
      {:ok, %{rows: [[id]]}} -> {:ok, id}
      {:ok, %{rows: []}} -> {:error, "Law not found in uk_lrt: #{law_name}"}
      {:error, err} -> {:error, "DB error: #{inspect(err)}"}
    end
  end

  defp fetch_body_xml(slash_path) do
    path = "/#{slash_path}/body/data.xml"

    case Client.fetch_xml(path) do
      {:ok, xml} -> {:ok, xml}
      {:ok, :html, _html} -> {:error, "Received HTML instead of XML for #{path}"}
      {:error, _code, reason} -> {:error, "Failed to fetch body XML: #{reason}"}
    end
  end
end
