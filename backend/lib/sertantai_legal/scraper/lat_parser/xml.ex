defmodule SertantaiLegal.Scraper.LatParser.Xml do
  @moduledoc """
  Shared CLML element helpers for the LAT parser (LR-04): element names,
  ids, extents, change ids, and the element-name sets every stage reads
  (which elements are rows, provisions, containers, skipped, quoted, never
  text). Pure; no other parser module is a dependency.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.Territory

  @container_elements ~w(Legislation Primary Secondary Body Schedules ScheduleBody
                         P1para P2para P3para P4para P1group P2group P3group
                         ScheduleBody FragmentBody
                         EURetained EUBody)

  # Elements to skip entirely — contain embedded P1/P2/P3 from OTHER laws or
  # alternative territorial versions that duplicate the primary text
  @skip_elements ~w(BlockAmendment AppendText BlockExtract
                    Versions Version Commentaries Commentary Contents)

  # Elements emitted as rows of their own: structural text stops at them.
  @row_elements ~w(Part EUTitle Chapter EUChapter Pblock P1 P2 P3 P4 Schedule
                   SignedSection Tabular Figure)

  # Provision rows that can take sibling content that follows them (#174)
  @provision_rows ~w(P1 P2 P3 P4)

  # Text another law gets (BlockAmendment, AppendText) or quoted material
  # (BlockExtract): one block, «…», with its provision numbers and titles —
  # the amending text is used to update records legislation.gov.uk applies
  # late (Jason, 2026-10-08). Its provisions are never rows of this law.
  @quoted_elements ~w(BlockAmendment AppendText BlockExtract)

  # Never text: numbers, titles (read by extract_title), reference markers.
  @no_text_elements ~w(Pnumber Number Title TitleBlock Reference CommentaryRef
                       FootnoteRef Footnotes Commentaries)

  @doc "Elements walked through without a row of their own."
  @spec container_elements() :: [String.t()]
  def container_elements, do: @container_elements

  @doc "Elements never walked (other laws' text, alternative versions, notes)."
  @spec skip_elements() :: [String.t()]
  def skip_elements, do: @skip_elements

  @doc "Elements emitted as rows of their own."
  @spec row_elements() :: [String.t()]
  def row_elements, do: @row_elements

  @doc "Provision rows that can take the sibling content after them (#174)."
  @spec provision_rows() :: [String.t()]
  def provision_rows, do: @provision_rows

  @doc "Quoted blocks: another law's text, rendered «…»."
  @spec quoted_elements() :: [String.t()]
  def quoted_elements, do: @quoted_elements

  @doc "Elements that are never text."
  @spec no_text_elements() :: [String.t()]
  def no_text_elements, do: @no_text_elements

  @doc "An element's name (`name(.)`)."
  @spec element_name(tuple()) :: String.t()
  def element_name(node) do
    xpath(node, ~x"name(.)"s)
  end

  @doc """
  A name without its prefix: "xhtml:td" (element atom) or
  "{http://www.w3.org/1999/xhtml}td" (XPath name()) → "td".
  """
  @spec local_name(atom() | String.t()) :: String.t()
  def local_name(name),
    do: name |> to_string() |> String.replace(~r/\A(\{[^}]*\}|[^:{]*:)/, "")

  @doc "nil for an empty string."
  @spec blank_to_nil(String.t()) :: String.t() | nil
  def blank_to_nil(""), do: nil
  def blank_to_nil(text), do: text

  @doc "Status=\"Prospective\" on the element."
  @spec prospective?(tuple()) :: boolean()
  def prospective?(node), do: xpath(node, ~x"./@Status"so) |> to_string() == "Prospective"

  @doc "The element's RestrictExtent, normalised (nil when none)."
  @spec element_extent(tuple()) :: String.t() | nil
  def element_extent(node) do
    case xpath(node, ~x"./@RestrictExtent"so) do
      nil -> nil
      "" -> nil
      val -> Territory.normalize(to_string(val))
    end
  end

  @doc "The document root's RestrictExtent, normalised (nil when none): a parsed document or XML."
  @spec root_extent(tuple() | String.t()) :: String.t() | nil
  def root_extent(xml) when is_binary(xml),
    do: xml |> SweetXml.parse(quiet: true) |> root_extent()

  def root_extent(doc) do
    doc
    |> xpath(~x"/*/@RestrictExtent"so)
    |> case do
      nil -> nil
      "" -> nil
      val -> Territory.normalize(to_string(val))
    end
  end

  @doc """
  The element's id attribute (e.g. id="section-1-1-a"): assigned by
  legislation.gov.uk, a stable join key whatever the parse.
  """
  @spec xml_id(tuple()) :: String.t() | nil
  def xml_id(node) do
    case xpath(node, ~x"./@id"s) do
      nil -> nil
      "" -> nil
      id -> to_string(id)
    end
  end

  @doc "A change element's ChangeId (nil when none)."
  @spec change_id(tuple()) :: String.t() | nil
  def change_id(element), do: blank_to_nil(xpath(element, ~x"./@ChangeId"s))
end
