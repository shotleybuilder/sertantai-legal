defmodule SertantaiLegal.Sync.Templates.Foundation do
  @moduledoc """
  Foundation template — Legal Register (LRT) + Legal Articles (LAT).

  This template declares the existing tables that Engine.run syncs.
  It doesn't create them (they're pre-provisioned in SyncConfiguration) —
  it serves as the dependency root so other templates can reference
  :lrt and :lat table keys.

  The actual row sync is handled by Engine.run, not by this template's
  seed callback.
  """

  @behaviour SertantaiLegal.Sync.Templates.TemplateBehaviour

  @impl true
  def id, do: :foundation

  @impl true
  def name, do: "Foundation — Legal Register + Provisions"

  @impl true
  def requires, do: []

  @impl true
  def tables, do: [:lrt, :lat]

  @impl true
  def field_specs(_sub_patterns) do
    # Foundation fields are managed by Engine.run via lrt_field_specs/lat_field_specs
    # in baserow.ex. This template declares the tables exist but doesn't
    # define fields — they're already created by the existing sync pipeline.
    %{lrt: [], lat: []}
  end

  @impl true
  def view_specs(_sub_patterns) do
    %{lrt: [], lat: []}
  end

  # No cross-table fields, webhooks, or seed — Engine.run handles everything.
end
