defmodule SertantaiLegal.Countries.Uk do
  @moduledoc """
  United Kingdom country module.

  Provides UK-specific legal data: type codes, geographic extents,
  family taxonomy, actor definitions, and legislation.gov.uk URL builder.

  Delegates to existing specialist modules where possible rather than
  duplicating data.
  """

  @behaviour SertantaiLegal.Countries.Country

  # ── Identity ──────────────────────────────────────────────────────

  @impl true
  def code, do: "uk"

  @impl true
  def name, do: "United Kingdom"

  @impl true
  def jurisdictions do
    [
      {"uk", "United Kingdom (all regions)"},
      {"eng", "England"},
      {"wal", "Wales"},
      {"sco", "Scotland"},
      {"ni", "Northern Ireland"}
    ]
  end

  # ── Type Codes ────────────────────────────────────────────────────

  @type_codes %{
    # UK Parliament
    "ukpga" => "Public General Act of the United Kingdom Parliament",
    "uksi" => "UK Statutory Instrument",
    "ukla" => "UK Local Act",
    "ukmo" => "UK Ministerial Order",
    "ukci" => "Church Instrument",
    # Scotland
    "asp" => "Act of the Scottish Parliament",
    "ssi" => "Scottish Statutory Instrument",
    # Northern Ireland
    "nisr" => "Northern Ireland Statutory Rule",
    "nisi" => "Northern Ireland Order in Council 1972-date",
    "nia" => "Act of the Northern Ireland Assembly",
    "apni" => "Act of the Parliament of Northern Ireland 1921-1972",
    # Wales
    "wca" => "Act of the National Assembly for Wales",
    "asc" => "Act of the Senedd Cymru 2020-date",
    "anaw" => "Act of the National Assembly for Wales 2012-2020",
    "wsi" => "Wales Statutory Instrument 2018-date",
    "mwa" => "Measure of the National Assembly for Wales 2008-2011",
    # EU retained
    "eur" => "EU Retained Legislation",
    "eudr" => "EU Directive",
    "eudn" => "EU Decision"
  }

  @impl true
  def type_codes, do: @type_codes

  @impl true
  def type_code_name(code), do: Map.get(@type_codes, code)

  @impl true
  def type_class_from_title(title) do
    SertantaiLegal.Scraper.TypeClass.set_type_class(%{Title_EN: title})
    |> Map.get(:type_class)
  end

  # ── Geographic Extents ────────────────────────────────────────────

  @geo_extents [
    {"E+W+S+NI", "UK-wide"},
    {"E+W+S", "Great Britain"},
    {"E+W+NI", "England, Wales & Northern Ireland"},
    {"E+W", "England & Wales"},
    {"E+S", "England & Scotland"},
    {"E+NI", "England & Northern Ireland"},
    {"S+NI", "Scotland & Northern Ireland"},
    {"W+S", "Wales & Scotland"},
    {"W+NI", "Wales & Northern Ireland"},
    {"E", "England"},
    {"W", "Wales"},
    {"S", "Scotland"},
    {"NI", "Northern Ireland"}
  ]

  @impl true
  def geo_extents, do: @geo_extents

  # ── Family Taxonomy ───────────────────────────────────────────────

  @impl true
  defdelegate family_keywords, to: SertantaiLegal.Legal.FamilyRules, as: :title_keywords

  @impl true
  def families do
    family_keywords() |> Map.keys() |> Enum.sort()
  end

  # ── Actor Definitions ─────────────────────────────────────────────

  @impl true
  def government_actors do
    SertantaiLegal.Legal.Taxa.ActorDefinitions.government()
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
  end

  @impl true
  def governed_actors do
    SertantaiLegal.Legal.Taxa.ActorDefinitions.governed()
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
  end

  # ── Source URL Builder ────────────────────────────────────────────

  @impl true
  def source_url(type_code, year, number)
      when is_binary(type_code) and is_integer(year) and is_binary(number) do
    "https://www.legislation.gov.uk/#{type_code}/#{year}/#{number}"
  end

  def source_url(_, _, _), do: nil
end
