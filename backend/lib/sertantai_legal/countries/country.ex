defmodule SertantaiLegal.Countries.Country do
  @moduledoc """
  Behaviour defining the interface that each country module must implement.

  Country modules provide jurisdiction-specific data: type codes, geographic
  extents, family taxonomy, actor definitions, and source URL builders.

  Algorithms (making detection, purpose classification, function calculation)
  live in their own modules and may call country modules for reference data.

  ## Usage

      iex> SertantaiLegal.Countries.Country.for("uk")
      SertantaiLegal.Countries.Uk

      iex> SertantaiLegal.Countries.Uk.type_code_name("ukpga")
      "Public General Act of the United Kingdom Parliament"
  """

  @typedoc "Country code (ISO alpha-2 lowercase)"
  @type country_code :: String.t()

  @typedoc "Sub-national jurisdiction code"
  @type jurisdiction_code :: String.t()

  # ── Registry ──────────────────────────────────────────────────────

  @doc "Return the country module for a given country code."
  @spec for(country_code()) :: module() | nil
  def for(code) do
    Map.get(registry(), code)
  end

  @doc "Return the country module for a given country code, raising if not found."
  @spec for!(country_code()) :: module()
  def for!(code) do
    case Map.get(registry(), code) do
      nil -> raise ArgumentError, "Unknown country code: #{inspect(code)}"
      mod -> mod
    end
  end

  @doc "List all registered country codes."
  @spec codes() :: [country_code()]
  def codes, do: Map.keys(registry())

  defp registry do
    %{
      "uk" => SertantaiLegal.Countries.Uk,
      "au" => SertantaiLegal.Countries.Au
    }
  end

  # ── Callbacks ─────────────────────────────────────────────────────

  @doc "Country code (e.g. \"uk\", \"au\")."
  @callback code() :: country_code()

  @doc "Human-readable country name (e.g. \"United Kingdom\")."
  @callback name() :: String.t()

  @doc "List of valid jurisdiction codes for this country."
  @callback jurisdictions() :: [{jurisdiction_code(), String.t()}]

  @doc "Map of type_code → full descriptive name (e.g. %{\"ukpga\" => \"Public General Act...\"})."
  @callback type_codes() :: %{String.t() => String.t()}

  @doc "Look up a type code's descriptive name. Returns nil if unknown."
  @callback type_code_name(String.t()) :: String.t() | nil

  @doc "Infer type_class from a law title (e.g. \"Act\", \"Regulation\"). Returns nil if unrecognised."
  @callback type_class_from_title(String.t()) :: String.t() | nil

  @doc "List of valid geographic extent codes with labels (e.g. [{\"E+W+S+NI\", \"UK-wide\"}, ...])."
  @callback geo_extents() :: [{String.t(), String.t()}]

  @doc """
  Family taxonomy: map of family name → keyword list for title-based matching.
  e.g. %{"💙 FIRE" => ["fire"], "💚 AGRICULTURE" => ["agriculture", ...]}
  """
  @callback family_keywords() :: %{String.t() => [String.t()]}

  @doc "List of all valid family names for this country."
  @callback families() :: [String.t()]

  @doc """
  Government actor patterns: list of {category, patterns} tuples.
  Patterns are strings or lists of strings (regex fragments).
  """
  @callback government_actors() :: [{String.t(), String.t() | [String.t()]}]

  @doc """
  Governed (non-government) actor patterns: list of {category, patterns} tuples.
  """
  @callback governed_actors() :: [{String.t(), String.t() | [String.t()]}]

  @doc "Build the authoritative source URL for a law given its type_code, year, and number."
  @callback source_url(type_code :: String.t(), year :: integer(), number :: String.t()) ::
              String.t() | nil
end
