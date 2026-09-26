defmodule SertantaiLegal.Scraper.LegislationGovUk.BodyXml do
  @moduledoc """
  Pure helpers over a legislation.gov.uk `/body/data.xml` response.

  Handles:
  - `pdf_links/1` — the PDF alternatives (`ukm:Alternative/@URI`) listed in the
    metadata. For laws published only as scanned PDFs, the body XML carries
    metadata and these links but no `Primary`/`Secondary` content.
  """

  import SweetXml

  @doc "The PDF URIs listed as alternatives in the body XML (`[]` if none or unparseable)."
  @spec pdf_links(String.t()) :: [String.t()]
  def pdf_links(xml) when is_binary(xml) do
    xml
    |> SweetXml.parse(quiet: true)
    |> xpath(~x"//*[local-name()='Alternative']/@URI"ls)
    |> Enum.filter(&String.ends_with?(&1, ".pdf"))
    |> Enum.uniq()
  catch
    :exit, _ -> []
  end
end
