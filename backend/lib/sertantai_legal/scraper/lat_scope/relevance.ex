defmodule SertantaiLegal.Scraper.LatScope.Relevance do
  @moduledoc """
  Relevance scopes for large Acts (#166): which legislation.gov.uk fragments
  an Act's LAT keeps.

  Rule (Jason, 2026-10-07): a large Act with no family keeps the whole Part
  of every section that an in-family register SI is made under (its EHS
  link), plus any fragments named for it. A cited section outside any Part
  (or not held in the LAT) stays a section fragment. A named fragment inside
  a kept Part is dropped, so nothing is fetched twice.

  Handles:
  - `fragments/3` — cited sections + named fragments → the scope's fragments
  - `covered?/2` — is a fragment already inside one of the others
  - `kept?/2` — would a LAT row survive narrowing to these fragments (for
    dry-run estimates)

  Pure: section → Part maps and citations are passed in.
  """

  @doc """
  Fragments for an Act. `section_parts` maps a section number to its Part
  (nil = not in a Part); `cited` are section numbers cited by in-family SIs;
  `named` are extra fragments (`part/2/chapter/2`).
  """
  @spec fragments(%{String.t() => String.t() | nil}, [String.t()], [String.t()]) :: [String.t()]
  def fragments(section_parts, cited, named) do
    from_cited =
      Enum.map(cited, fn section ->
        case Map.get(section_parts, section) do
          nil -> "section/#{section}"
          part -> "part/#{part}"
        end
      end)

    base = Enum.uniq(from_cited)
    base ++ (named |> Enum.uniq() |> Enum.reject(&(&1 in base or covered?(&1, base))))
  end

  @doc "Whether `fragment` lies inside one of `others` (a Part covers its chapters)."
  @spec covered?(String.t(), [String.t()]) :: boolean()
  def covered?(fragment, others) do
    Enum.any?(others, fn other ->
      other != fragment and String.starts_with?(fragment, other <> "/")
    end)
  end

  @doc "Whether a LAT row (`part`, `chapter`, `provision`) falls inside `fragments`."
  @spec kept?(map(), [String.t()]) :: boolean()
  def kept?(row, fragments) do
    Enum.any?(fragments, fn fragment ->
      case String.split(fragment, "/") do
        ["part", p] -> row.part == p
        ["part", p, "chapter", c] -> row.part == p and row.chapter == c
        ["section", n] -> row.provision == n
        ["article", n] -> row.provision == n
        ["schedule", n] -> Map.get(row, :schedule) == n
        _ -> false
      end
    end)
  end
end
