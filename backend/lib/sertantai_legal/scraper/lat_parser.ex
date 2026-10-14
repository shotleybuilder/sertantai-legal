defmodule SertantaiLegal.Scraper.LatParser do
  @moduledoc """
  Parses legislation.gov.uk body XML into LAT (Legal Articles Table) rows.

  Pure function module — takes body XML string + law context, returns a list
  of LAT row maps ready for persistence. No HTTP calls, no side effects.

  ## Usage

      rows = LatParser.parse(xml_string, %{
        law_name: "UK_ukpga_1974_37",
        type_code: "ukpga"
      })

  ## XML Element Mapping

  | XML Element     | section_type              |
  |-----------------|---------------------------|
  | Part            | part                      |
  | Chapter         | chapter                   |
  | Pblock          | heading                   |
  | P1              | section (Acts) / article  |
  | P2              | sub_section / sub_article |
  | P3              | paragraph                 |
  | P4              | sub_paragraph             |
  | SignedSection    | signed                    |
  | Tabular         | table                     |
  | Figure          | note                      |

  `Schedules` and `Schedule` give no rows: no schedules in LAT (LR-10).
  """

  alias SertantaiLegal.Scraper.LatParser.{Rows, SortKey, Walker}
  alias SertantaiLegal.Scraper.LatParser.Walker.Ctx

  @doc """
  Parse body XML into a list of LAT row maps.

  ## Parameters

    - `xml` — raw XML string from legislation.gov.uk `/body/data.xml`
    - `context` — map with `:law_name` and `:type_code`

  ## Returns

  List of maps with keys matching LAT table columns.
  """
  @type context :: %{
          required(:law_name) => String.t(),
          required(:type_code) => String.t(),
          optional(:effects) => list() | map() | nil,
          optional(atom()) => term()
        }

  @spec parse(String.t(), context()) :: [map()]
  def parse(xml, context) when is_binary(xml) do
    mode = Rows.mode(context.type_code)
    doc = SweetXml.parse(xml, quiet: true)

    doc
    |> Walker.walk(Ctx.new(doc, context))
    |> Rows.drop_repeated_versions()
    |> Rows.assign_positions()
    |> Rows.build_fields(context.law_name, mode, context.type_code)
    |> Rows.mark_repealed(mode)
    |> Rows.assign_status()
    |> Rows.qualify_parallels()
    |> Rows.disambiguate()
    # Keys must ascend with document order even where the numbering or the
    # source markup defeats the hierarchical encoding.
    |> SortKey.monotonic()
  end

  @doc "Convert parsed rows to maps for `Repo.insert_all/3` (`Rows.to_insert_maps/2`)."
  defdelegate to_insert_maps(rows, law_id), to: Rows
end
