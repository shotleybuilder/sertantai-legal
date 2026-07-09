defmodule SertantaiLegal.Sync do
  @moduledoc """
  Ash Domain for the Subscription & Sync Service.

  Manages organisation entitlements (what they can sync), sync profiles
  (user-curated filters within entitlement bounds), and sync configurations
  (provider connections for pushing data to external tools like Baserow).
  """

  use Ash.Domain

  resources do
    resource(SertantaiLegal.Sync.Organization)
    resource(SertantaiLegal.Sync.OrgEntitlement)
    resource(SertantaiLegal.Sync.SyncProfile)
    resource(SertantaiLegal.Sync.SyncConfiguration)
    resource(SertantaiLegal.Sync.SyncJob)
    resource(SertantaiLegal.Sync.SyncRowMapping)
    resource(SertantaiLegal.Sync.OrgApplicability)
    resource(SertantaiLegal.Sync.OrgScreeningProfile)
    resource(SertantaiLegal.Sync.ApplicabilityEvent)
  end
end
