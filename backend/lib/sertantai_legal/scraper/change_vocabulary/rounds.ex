defmodule SertantaiLegal.Scraper.ChangeVocabulary.Rounds do
  @moduledoc """
  The rounds of families that run the LAT Change Pipeline's steps together
  (Tooling: round scope, Jason 2026-11-13), each by its families' exact
  register names, the display marker dropped (as
  `LabelSwitch.family_in?/2`). A task's `--family` takes a round's name;
  `Amendment.PatternSource` scopes it to exactly these families, never a
  substring (`"OH&S"` would take in the switched Occupational family).
  `resolve/2` turns any `--family` name into the families it means: a
  round's, the one family named exactly, or the one family the name is
  part of; a name inside several families is refused (Store and build,
  2026-11-16: `--family "OH&S"` built four families).
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

  @doc """
  The register families (display marker dropped) a `--family` name means,
  given every register family name: a round's families; the family named
  exactly; else the one family whose name contains it. An error naming the
  matches when it is in several families or none.
  """
  @spec resolve(String.t(), [String.t()]) :: {:ok, [String.t()]} | {:error, String.t()}
  def resolve(name, register_families) do
    case families(name) do
      nil ->
        resolve_plain(unmarked(name), register_families |> Enum.map(&unmarked/1) |> Enum.uniq())

      names ->
        {:ok, names}
    end
  end

  defp resolve_plain(name, fams) do
    if name in fams, do: {:ok, [name]}, else: one_containing(name, fams)
  end

  defp one_containing(name, fams) do
    case fams |> Enum.filter(&String.contains?(&1, name)) |> Enum.sort() do
      [one] ->
        {:ok, [one]}

      [] ->
        {:error, "--family #{inspect(name)}: no family has that name"}

      many ->
        {:error,
         "--family #{inspect(name)} is in #{length(many)} families (#{Enum.join(many, "; ")}): name one exactly"}
    end
  end

  # the register's display marker (an emoji and a space) dropped, as the SQL does
  defp unmarked(name), do: String.replace(name, ~r/^[^[:alnum:]]+/u, "")

  @doc """
  True when a `--family` name is switched in `fams` (the `:label_families`
  setting, display markers dropped): a round every one of whose families
  is in it, else the family named (Fire and OH&S: Switch-over,
  2026-11-17: a round applied in one run). As `LabelSwitch.family_in?/2`,
  kept here so the labels stage's version holds no scope.
  """
  @spec switched?(String.t(), [String.t()]) :: boolean()
  def switched?(name, fams) do
    case families(name) do
      nil -> unmarked(name) in fams
      round -> Enum.all?(round, &(&1 in fams))
    end
  end

  @doc "True when `name` is a round's name."
  @spec round?(String.t()) :: boolean()
  def round?(name), do: Map.has_key?(@rounds, name)
end
