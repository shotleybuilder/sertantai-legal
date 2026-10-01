defmodule SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed do
  @moduledoc """
  The structured "changes affected" feed
  (`/changes/affected/{type}/{year}/{number}/data.feed`): one `ukm:Effect` per
  change to a law, with what the HTML changes table drops —

  - `AffectedExtent` — the extent of the affected provision (for a
    whole-instrument effect, of the law);
  - `AffectingEffectsExtent` — the extent of the change itself;
  - `AffectingTerritorialApplication` — where the change applies.

  Also, per effect (#168): `InForce` — the in-force `Date` (earliest when
  staged) or `Prospective` (not yet in force), with its Qualification;
  `Savings` provision refs; and the structured `AffectedProvisions` refs
  (`section-83-2-a`), which map to section_ids more reliably than the text.

  These are legislation.gov.uk editorial data: `LiveStatus` decides where a
  revocation reaches from them. `parse/1` is pure; `fetch/3` pages through the
  feed via `Client.fetch_xml/1`.
  """

  import SweetXml, except: [parse: 1, parse: 2]

  alias SertantaiLegal.Scraper.IdField
  alias SertantaiLegal.Scraper.LegislationGovUk.Client

  @results_per_page 500
  @max_pages 20

  defmodule Effect do
    @moduledoc "One `ukm:Effect` from the changes feed."
    @enforce_keys [:type, :affecting]
    defstruct [
      :type,
      :affecting,
      :affected_provisions,
      :affected_extent,
      :effect_extent,
      :territorial_application,
      :applied,
      :requires_applied,
      # #168: in-force data, savings and structured affected refs
      :in_force_date,
      :in_force_qualification,
      prospective: false,
      savings: [],
      affected_refs: []
    ]

    @type t :: %__MODULE__{
            type: String.t(),
            affecting: String.t() | nil,
            affected_provisions: String.t() | nil,
            affected_extent: String.t() | nil,
            effect_extent: String.t() | nil,
            territorial_application: String.t() | nil,
            applied: boolean() | nil,
            requires_applied: boolean() | nil,
            in_force_date: Date.t() | nil,
            in_force_qualification: String.t() | nil,
            prospective: boolean(),
            savings: [String.t()],
            affected_refs: [String.t()]
          }
  end

  @doc "Every effect on a law, across all feed pages."
  @spec fetch(String.t(), integer() | String.t(), String.t()) ::
          {:ok, [Effect.t()]} | {:error, String.t()}
  def fetch(type_code, year, number), do: fetch_page(type_code, year, number, 1, [])

  defp fetch_page(_t, _y, _n, page, _acc) when page > @max_pages,
    do: {:error, "changes feed exceeded #{@max_pages} pages"}

  defp fetch_page(type_code, year, number, page, acc) do
    path =
      "/changes/affected/#{type_code}/#{year}/#{number}/data.feed?results-count=#{@results_per_page}&page=#{page}"

    case Client.fetch_xml(path) do
      {:ok, xml} when is_binary(xml) ->
        case safe_parse(xml) do
          {:ok, {effects, %{more_pages?: true}}} ->
            fetch_page(type_code, year, number, page + 1, acc ++ effects)

          {:ok, {effects, _}} ->
            {:ok, acc ++ effects}

          {:error, msg} ->
            {:error, "changes feed unparseable for #{path}: #{msg}"}
        end

      {:ok, :html, _} ->
        {:error, "changes feed returned HTML for #{path}"}

      {:error, code, msg} ->
        {:error, "changes feed #{code}: #{msg}"}
    end
  end

  defp safe_parse(xml) do
    if String.contains?(xml, "<feed"), do: {:ok, parse(xml)}, else: {:error, "not an Atom feed"}
  rescue
    e -> {:error, Exception.message(e)}
  catch
    :exit, reason -> {:error, inspect(reason)}
  end

  @doc "Parse one feed page: its effects and whether more pages follow."
  @spec parse(String.t()) :: {[Effect.t()], %{page: integer(), more_pages?: boolean()}}
  def parse(xml) do
    doc = SweetXml.parse(xml, namespace_conformant: true)

    effects =
      doc
      |> xpath(
        ~x"//ukm:Effect"l
        |> add_namespace("ukm", "http://www.legislation.gov.uk/namespaces/metadata"),
        type: ~x"./@Type"s,
        affecting_uri: ~x"./@AffectingURI"s,
        affected_provisions: ~x"./@AffectedProvisions"s,
        affected_extent: ~x"./@AffectedExtent"s,
        effect_extent: ~x"./@AffectingEffectsExtent"s,
        territorial_application: ~x"./@AffectingTerritorialApplication"s,
        applied: ~x"./@Applied"s,
        requires_applied: ~x"./@RequiresApplied"s,
        # child elements by local name (the ukm namespace is on the parent query)
        in_force: [
          ~x"./*[local-name()='InForceDates']/*[local-name()='InForce']"l,
          date: ~x"./@Date"s,
          prospective: ~x"./@Prospective"s,
          qualification: ~x"./@Qualification"s
        ],
        savings: ~x"./*[local-name()='Savings']/*[local-name()='Section']/@Ref"ls,
        affected_refs: ~x"./*[local-name()='AffectedProvisions']//*[@Ref]/@Ref"ls
      )
      |> Enum.map(fn e ->
        %Effect{
          type: e.type,
          affecting: law_name(blank(e.affecting_uri)),
          affected_provisions: blank(e.affected_provisions),
          affected_extent: blank(e.affected_extent),
          effect_extent: blank(e.effect_extent),
          territorial_application: blank(e.territorial_application),
          applied: bool(e.applied),
          requires_applied: bool(e.requires_applied),
          in_force_date: earliest_date(e.in_force),
          in_force_qualification:
            e.in_force |> Enum.map(& &1.qualification) |> Enum.find(&(&1 != "")),
          prospective:
            Enum.any?(e.in_force, &(&1.prospective == "true")) and
              earliest_date(e.in_force) == nil,
          savings: e.savings,
          affected_refs: e.affected_refs
        }
      end)

    page =
      doc
      |> xpath(
        ~x"//leg:page/text()"s
        |> add_namespace("leg", "http://www.legislation.gov.uk/namespaces/legislation")
      )
      |> to_int(1)

    more =
      doc
      |> xpath(
        ~x"//leg:morePages/text()"s
        |> add_namespace("leg", "http://www.legislation.gov.uk/namespaces/legislation")
      )
      |> to_int(0)

    {effects, %{page: page, more_pages?: more > 0}}
  end

  @doc """
  Add each effect's extents to the changes-table revocation rows it matches
  (`lookup/4`), marking each row `feed: "matched" | "unmatched"`. With no
  effects (feed unavailable) rows are returned unchanged.
  """
  @spec enrich([map()], [Effect.t()]) :: [map()]
  def enrich(rows, []), do: rows

  def enrich(rows, effects) do
    index = index(effects)

    Enum.map(rows, fn row ->
      case lookup(index, row.name, row[:target], row[:affect]) do
        %Effect{} = e ->
          Map.merge(row, %{
            feed: "matched",
            affected_extent: e.affected_extent,
            effect_extent: e.effect_extent,
            territorial_application: e.territorial_application
          })

        nil ->
          Map.put(row, :feed, "unmatched")
      end
    end)
  end

  @whole_words ~w(act acts regulations regulation order rules scheme measure charter byelaws instrument directive decision)

  @doc "An index of effects for `lookup/4`."
  @spec index([Effect.t()]) :: %{exact: map(), whole: map()}
  def index(effects) do
    %{
      exact: Enum.group_by(effects, &{&1.affecting, norm(&1.affected_provisions), norm(&1.type)}),
      whole:
        effects
        |> Enum.filter(&(whole_target?(&1.affected_provisions) and revocation_type?(&1.type)))
        |> Enum.group_by(& &1.affecting)
    }
  end

  @doc """
  The effect for a changes-table row: same revoking law, target =
  `AffectedProvisions` and affect = `Type` (case and whitespace normalised);
  else, for a whole-instrument revocation row (blank target or an instrument
  word — the two sources name it differently: "" / "Regulation", "Act" /
  "Regulations", "revoked" / "repealed"), the same revoker's
  whole-instrument revocation effect.
  """
  @spec lookup(map(), String.t(), String.t() | nil, String.t() | nil) :: Effect.t() | nil
  def lookup(index, by, target, affect) do
    case Map.get(index.exact, {by, norm(target), norm(affect)}) do
      [e | _] ->
        e

      nil ->
        if whole_target?(target) and revocation_type?(affect) do
          case Map.get(index.whole, by) do
            [e | _] -> e
            nil -> nil
          end
        end
    end
  end

  defp whole_target?(t), do: norm(t) == "" or norm(t) in @whole_words
  defp revocation_type?(t), do: Regex.match?(~r/repeal|revoke|^rev$|^rep$/, norm(t))

  @min_provision_extents 3

  @doc """
  `AffectedExtent` evidence for the law's own extent (`ExtentResolver`
  `affected_effects`): the extent on its whole-instrument effects when there
  are any; otherwise the distinct provision-level extents, but only when at
  least #{@min_provision_extents} effects carry one — a single provision's
  extent is not the law's (PUWER 1992: 1 of 12 effects, "E+N.I.").
  """
  @spec affected_extents([Effect.t()]) :: [String.t()]
  def affected_extents(effects) do
    whole =
      for e <- effects,
          whole_target?(e.affected_provisions),
          e.affected_extent,
          do: e.affected_extent

    provisions = for e <- effects, e.affected_extent, do: e.affected_extent

    cond do
      whole != [] -> Enum.uniq(whole)
      length(provisions) >= @min_provision_extents -> Enum.uniq(provisions)
      true -> []
    end
  end

  defp norm(nil), do: ""
  defp norm(s), do: s |> String.downcase() |> String.replace(~r/\s+/, " ") |> String.trim()

  @doc "`UK_{type}_{year}_{number}` from a legislation.gov.uk `/id/` URI."
  @spec law_name(String.t() | nil) :: String.t() | nil
  def law_name(nil), do: nil

  def law_name(uri) do
    case Regex.run(~r"/id/([a-z]+)/(\d{4})/([^/]+)", uri) do
      [_, type, year, number] -> IdField.build_uk_id(type, year, number)
      _ -> nil
    end
  end

  # An effect can commence in stages (several InForce dates): the first.
  defp earliest_date(in_force) do
    in_force
    |> Enum.flat_map(fn f ->
      case Date.from_iso8601(f.date) do
        {:ok, d} -> [d]
        _ -> []
      end
    end)
    |> Enum.min(Date, fn -> nil end)
  end

  defp blank(""), do: nil
  defp blank(s), do: s

  defp bool("true"), do: true
  defp bool("false"), do: false
  defp bool(_), do: nil

  defp to_int(s, default) do
    case Integer.parse(s || "") do
      {n, _} -> n
      :error -> default
    end
  end
end
