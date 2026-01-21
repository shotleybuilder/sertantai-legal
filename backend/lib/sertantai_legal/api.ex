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
    # UK Legal Register Table - shared reference data (no organization_id)
    resource(SertantaiLegal.Legal.UkLrt)

    # Scraper session tracking
    resource(SertantaiLegal.Scraper.ScrapeSession)
    resource(SertantaiLegal.Scraper.ScrapeSessionRecord)

    # Tenant-scoped resources (require organization_id from JWT):
    # resource(SertantaiLegal.Legal.OrganizationLocation)
    # resource(SertantaiLegal.Legal.LocationScreening)
  end
end
