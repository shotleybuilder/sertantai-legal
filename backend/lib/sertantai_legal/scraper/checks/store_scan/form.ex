defmodule SertantaiLegal.Scraper.Checks.StoreScan.Form do
  @moduledoc """
  A form the store scan looks for (#192): a name, and a test of one
  stored feed effect that gives the class it falls in, or nil.
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @doc "The form's name, as `mix lat.store_scan --form` takes it."
  @callback name() :: String.t()

  @doc "The effect's class within the form, or nil when the form doesn't fit it."
  @callback match(Effect.t()) :: String.t() | nil
end
