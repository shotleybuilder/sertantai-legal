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
    # Domain resources will be added here:
    # resource(SertantaiLegal.Legal.UkLrt)
    # resource(SertantaiLegal.Legal.OrganizationLocation)
    # resource(SertantaiLegal.Legal.LocationScreening)
  end
end
