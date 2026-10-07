defmodule SertantaiLegal.Scraper.LatReparser do
  @moduledoc """
  Standalone LAT + Commentary re-parse for a single law (the admin
  re-parse, `LatAdminController.reparse/2`).

  A thin wrapper over `LatStagedParser.parse/2`, so it fetches what the
  law's `lat_scope` says (#166: a scoped law is never re-widened to its
  whole body) and records the parse cause, notes and status like every other
  parse path. A no-body (PDF-only) law comes back as an error with its LAT
  kept.
  """

  alias SertantaiLegal.Scraper.LatStagedParser

  @spec reparse(String.t(), (String.t() -> {:ok, map()} | {:error, String.t()})) ::
          {:ok, map()} | {:error, String.t()}
  def reparse(law_name, parse \\ &LatStagedParser.parse/1) when is_binary(law_name) do
    case parse.(law_name) do
      {:ok, %{has_errors: true} = result} -> {:error, result[:error] || "parse failed"}
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end
