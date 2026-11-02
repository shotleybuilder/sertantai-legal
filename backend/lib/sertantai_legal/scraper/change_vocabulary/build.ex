defmodule SertantaiLegal.Scraper.ChangeVocabulary.Build do
  @moduledoc """
  A law's merged changes built and stored (CV-04, CV-S11): its CLML body,
  its LAT rows, its feed effects and the primary sources
  (`Primary`) read into `ChangeVocabulary.changes/5`, written to
  `provision_changes` (`Store.write/3`) with what the build read
  (`Store.Inputs`). Moved out of `mix lat.vocabulary` (CV-06) so the label
  refresh can build a switched family's law after its parse.

  Reads the database and the local CLML store; `law/1` writes the law's
  changes.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{ChangeVocabulary, LatStagedParser}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Ref, Store}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Primary

  @doc "The primary sources' options for `law` (`Primary.primary/2`)."
  @spec primary(String.t(), [map()]) :: keyword()
  defdelegate primary(law, effects), to: Primary

  @doc "The law's title in the register (`Primary.title/1`)."
  @spec title(String.t()) :: String.t() | nil
  defdelegate title(law), to: Primary

  @doc "Build and store `law`'s merged changes; a line of its counts."
  @spec law(String.t()) :: String.t()
  def law(law) do
    xml = clml(law)

    effects =
      law
      |> LatStagedParser.law_effects(store: :only)
      |> LatStagedParser.with_affecting_territory(law)

    all = rows(law)
    opts = law |> primary(effects) |> Keyword.merge(rows: Map.keys(all), xml_ids: xml_ids(law))
    changes = ChangeVocabulary.changes(law, xml, effects, all, opts)
    {:ok, n} = Store.write(law, changes, inputs(law, effects, opts))
    "#{n.changes} changes, #{n.claims} claims"
  end

  # every LAT row of the law, with its extent (the change's bound)
  @doc "Every LAT row of `law` with its extent."
  @spec rows(String.t()) :: %{String.t() => map()}
  def rows(law) do
    %{rows: rows} =
      Repo.query!(
        "SELECT section_id, extent_code FROM legal_articles WHERE law_name = $1 AND section_id IS NOT NULL",
        [law]
      )

    for [sid, ext] <- rows,
        into: %{},
        do: {String.replace_prefix(sid, law <> ":", ""), %{extent: ext}}
  end

  # each LAT row's XML id → its ref, as the parse named it (versions share
  # their base: "section-23" → "s.23")
  @doc "Each LAT row's XML id → its ref, as the parse named it."
  @spec xml_ids(String.t()) :: map()
  def xml_ids(law) do
    Ref.xml_ids(
      law,
      Repo.query!(
        "SELECT section_id, source_xml_id FROM legal_articles WHERE law_name = $1 AND source_xml_id IS NOT NULL",
        [law]
      ).rows
    )
  end

  # what the build read, for staleness (`Store.Inputs`, `ChangeStaleness`)
  @doc "What the build read, for staleness (`Store.Inputs`)."
  @spec inputs(String.t(), [map()], keyword()) :: map()
  def inputs(law, effects, opts) do
    affecting = effects |> Enum.map(& &1.affecting) |> Enum.reject(&is_nil/1) |> Enum.uniq()

    law
    |> Store.Inputs.of(affecting, Map.keys(opts[:commencement]))
    |> Map.put(:extents_unread, opts[:extents_unread])
  end

  @doc "The law's stored CLML body."
  @spec clml(String.t()) :: binary()
  def clml(law) do
    [_, type, year, num] = String.split(law, "_", parts: 4)

    case Path.wildcard("data/cache/clml/#{type}/#{year}/#{num}/body/data.xml.gz") do
      [path | _] -> path |> File.read!() |> :zlib.gunzip()
      [] -> raise ArgumentError, "no stored CLML body for #{law}"
    end
  end
end
