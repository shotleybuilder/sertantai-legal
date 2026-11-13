defmodule SertantaiLegal.Scraper.ChangeVocabulary.Rounds do
  @moduledoc """
  The rounds of families that run the LAT Change Pipeline's steps together
  (Tooling: round scope, Jason 2026-11-13), each by its families' exact
  register names, the display marker dropped (as
  `LabelSwitch.family_in?/2`). A task's `--family` takes a round's name;
  `Amendment.PatternSource` scopes it to exactly these families, never a
  substring (`"OH&S"` would take in the switched Occupational family).
  Outside `ChangeVocabulary.Version`'s files: a scope, never what a build
  reads. Pure.
  """

  @rounds %{
    "Fire and OH&S" => [
      "FIRE",
      "FIRE: Dangerous and Explosive Substances",
      "OH&S: Gas & Electrical Safety",
      "OH&S: Mines & Quarries",
      "OH&S: Offshore Safety"
    ]
  }

  @doc "Every round's name."
  @spec names() :: [String.t()]
  def names, do: @rounds |> Map.keys() |> Enum.sort()

  @doc "A round's family names, or nil when `name` is a plain family."
  @spec families(String.t()) :: [String.t()] | nil
  def families(name), do: Map.get(@rounds, name)

  @doc "True when `name` is a round's name."
  @spec round?(String.t()) :: boolean()
  def round?(name), do: Map.has_key?(@rounds, name)
end
