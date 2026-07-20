defmodule SertantaiLegal.Api do
  @moduledoc """
  The main Ash Domain for Sertantai-Legal.

  This domain contains resources for UK Legal/Regulatory compliance:

  ## Domain Resources (to be added)
  - UkLrt: UK Legal/Regulatory Transport records (19K+ reference data)
  - OrganizationLocation: Business locations for compliance screening
  - LocationScreening: Screening results and history

  ## Authentication
  This service does NOT own User/Organization resources.
  - Authentication is handled by sertantai-auth via JWT validation
  - organization_id comes from JWT claims
  - User identity is validated via SHARED_TOKEN_SECRET
  """

  use Ash.Domain

  resources do
    # Multi-jurisdiction Legal Register (partitioned by country)
    resource(SertantaiLegal.Legal.LegalRegister)

    # Multi-jurisdiction Legal Articles (partitioned by country)
    resource(SertantaiLegal.Legal.LegalArticle)

    # Legacy aliases — backed by views, kept for backwards compatibility during transition
    resource(SertantaiLegal.Legal.UkLrt)
    resource(SertantaiLegal.Legal.Lat)

    # Amendment Annotations - legislative change footnotes linked to LAT sections
    resource(SertantaiLegal.Legal.AmendmentAnnotation)

    # AI-generated controls and provision mappings (from fractalaw)
    resource(SertantaiLegal.Legal.Control)
    resource(SertantaiLegal.Legal.ControlMapping)

    # AI-generated evidence patterns and artefact templates (from fractalaw)
    resource(SertantaiLegal.Legal.EvidencePattern)
    resource(SertantaiLegal.Legal.ArtefactTemplate)

    # Second-tier compliance requirements (ACoPs, standards, JSPs, guidance)
    resource(SertantaiLegal.Legal.SecondarySource)
    resource(SertantaiLegal.Legal.SecondarySourceProvision)
    resource(SertantaiLegal.Legal.SourceLink)
    resource(SertantaiLegal.Legal.SecondaryObligation)
    resource(SertantaiLegal.Legal.SecondaryRaci)
    resource(SertantaiLegal.Legal.SecondaryMandatedArtefact)
    resource(SertantaiLegal.Legal.SecondaryTerm)

    # Scraper session tracking
    resource(SertantaiLegal.Scraper.ScrapeSession)
    resource(SertantaiLegal.Scraper.ScrapeSessionRecord)
    resource(SertantaiLegal.Scraper.CascadeAffectedLaw)

    # Tenant-scoped resources (require organization_id from JWT):
    # resource(SertantaiLegal.Legal.OrganizationLocation)
    # resource(SertantaiLegal.Legal.LocationScreening)
  end
end
