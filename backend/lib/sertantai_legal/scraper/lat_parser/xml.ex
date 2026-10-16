defmodule SertantaiLegal.Scraper.LatParser.Xml do
  @moduledoc """
  Shared CLML element helpers for the LAT parser (LR-04): element names,
  ids, extents, change ids, and the element-name sets every stage reads
  (which elements are rows, provisions, containers, skipped, quoted, never
  text). Pure; no other parser module is a dependency.
  """

  import SweetXml

  require Record

  alias SertantaiLegal.Scraper.Territory

  # xmerl's records, read directly (LR-31 E2): `SweetXml.xpath/2` re-parses
  # its path string on every call, about half the LAT walk's time
  Record.defrecordp(
    :xml_element,
    :xmlElement,
    Record.extract(:xmlElement, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(
    :xml_attribute,
    :xmlAttribute,
    Record.extract(:xmlAttribute, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(
    :xml_text,
    :xmlText,
    Record.extract(:xmlText, from_lib: "xmerl/include/xmerl.hrl")
  )

  Record.defrecordp(
    :xml_namespace,
    :xmlNamespace,
    Record.extract(:xmlNamespace, from_lib: "xmerl/include/xmerl.hrl")
  )

  @container_elements ~w(Legislation Primary Secondary Body
                         P1para P2para P3para P4para P1group P2group P3group
                         FragmentBody
                         EURetained EUBody)

  # No schedules in LAT (LR-10, Jason 2026-10-12): compliance v0.1 ships
  # without them. A Schedule still bounds structural text like a row would.
  @schedule_elements ~w(Schedules Schedule)

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

  @doc "Schedule elements: never walked, so no LAT row comes from a Schedule (LR-10)."
  @spec schedule_elements() :: [String.t()]
  def schedule_elements, do: @schedule_elements

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

  @doc """
  An element's name, as XPath `name(.)` gives it: "{uri}Local" for a
  prefixed name whose namespace is declared, else the name ("P1").
  """
  @spec element_name(tuple()) :: String.t()
  def element_name(xml_element(name: name, nsinfo: nsinfo, namespace: ns)) do
    case nsinfo do
      {prefix, local} ->
        case List.keyfind(xml_namespace(ns, :nodes), prefix, 0) do
          {_, uri} -> "{#{uri}}#{local}"
          nil -> to_string(local)
        end

      [] ->
        Atom.to_string(name)
    end
  end

  def element_name(_node), do: ""

  @doc "An element's attribute value, \"\" when absent (`./@Name` with `s`)."
  @spec attr(tuple(), atom()) :: String.t()
  def attr(node, name), do: attr_or_nil(node, name) || ""

  @doc "An element's attribute value, nil when absent (`./@Name` with `so`)."
  @spec attr_or_nil(tuple(), atom()) :: String.t() | nil
  def attr_or_nil(xml_element(attributes: attributes), name) do
    case List.keyfind(attributes, name, xml_attribute(:name)) do
      nil -> nil
      a -> a |> xml_attribute(:value) |> to_string()
    end
  end

  def attr_or_nil(_node, _name), do: nil

  @doc "Child elements (`./*`), or those named `name` (`./Name`)."
  @spec children(tuple()) :: [tuple()]
  def children(xml_element(content: content)),
    do: Enum.filter(content, &Record.is_record(&1, :xmlElement))

  def children(_node), do: []

  @spec children(tuple(), atom()) :: [tuple()]
  def children(node, name),
    do: node |> children() |> Enum.filter(&(xml_element(&1, :name) == name))

  @doc "Descendant elements in document order (`.//*`), or those named in `names` (`.//Name`)."
  @spec descendants(tuple()) :: [tuple()]
  def descendants(node), do: node |> children() |> Enum.flat_map(&[&1 | descendants(&1)])

  @spec descendants(tuple(), atom() | [atom()]) :: [tuple()]
  def descendants(node, names) do
    names = List.wrap(names)
    node |> descendants() |> Enum.filter(&(xml_element(&1, :name) in names))
  end

  @doc """
  Descendant elements in xmerl's `.//*` order, or those named in `names`:
  each node's children in turn, for the node and then its descendants in
  document order — not document order (`descendants/1,2`). Kept where the
  xpath it replaced fed an ordered result, so LR-31's refactor changes no
  output (LR-35 moved `EffectTarget` to document order).
  """
  @spec descendants_xmerl(tuple()) :: [tuple()]
  def descendants_xmerl(node), do: Enum.flat_map([node | descendants(node)], &children/1)

  @spec descendants_xmerl(tuple(), atom() | [atom()]) :: [tuple()]
  def descendants_xmerl(node, names) do
    names = List.wrap(names)
    node |> descendants_xmerl() |> Enum.filter(&(xml_element(&1, :name) in names))
  end

  @doc "Whether any descendant element is named in `names` (`.//Name[1]` exists)."
  @spec descendant?(tuple(), atom() | [atom()]) :: boolean()
  def descendant?(node, names), do: find_descendant(children(node), List.wrap(names))

  defp find_descendant([], _names), do: false

  defp find_descendant([el | rest], names),
    do:
      xml_element(el, :name) in names or find_descendant(children(el), names) or
        find_descendant(rest, names)

  @doc "Descendant text in document order (`./descendant::text()` with `ls`)."
  @spec texts(tuple()) :: [String.t()]
  def texts(xml_element(content: content)), do: Enum.flat_map(content, &texts/1)
  def texts(xml_text(value: value)), do: [to_string(value)]
  def texts(_node), do: []

  @doc "An element's local name atom (`P1`, `Title`)."
  @spec tag(tuple()) :: atom() | nil
  def tag(xml_element(name: name)), do: name
  def tag(_node), do: nil

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
  def prospective?(node), do: attr_or_nil(node, :Status) == "Prospective"

  @doc "The element's RestrictExtent, normalised (nil when none)."
  @spec element_extent(tuple()) :: String.t() | nil
  def element_extent(node) do
    case attr_or_nil(node, :RestrictExtent) do
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
  def xml_id(node), do: blank_to_nil(attr(node, :id))

  @doc "A change element's ChangeId (nil when none)."
  @spec change_id(tuple()) :: String.t() | nil
  def change_id(element), do: blank_to_nil(attr(element, :ChangeId))
end
