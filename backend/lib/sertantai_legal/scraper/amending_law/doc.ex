defmodule SertantaiLegal.Scraper.AmendingLaw.Doc do
  @moduledoc """
  An amending law's CLML, parsed once (lat-refactor LR-08): its documents
  (body and Schedules) as one set of elements by id, in document order,
  with the title of the nearest container over each (a Part titled
  "Electricity Act 1989", a cross-heading) and the enactment date. The
  other `AmendingLaw` readers take this, never raw XML. Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LatParser.Xml

  @enforce_keys [:law_name, :type]
  defstruct [
    :law_name,
    :type,
    :enactment_date,
    ids: [],
    pos: %{},
    elements: %{},
    titles: %{},
    roots: []
  ]

  @type t :: %__MODULE__{
          law_name: String.t(),
          type: String.t(),
          enactment_date: Date.t() | nil,
          ids: [String.t()],
          pos: %{String.t() => non_neg_integer()},
          elements: %{String.t() => tuple()},
          titles: %{String.t() => String.t()},
          roots: [tuple()]
        }

  @doc "Parse a law's documents (`xmls`: body, Schedules)."
  @spec new(String.t(), [String.t()]) :: t()
  def new(law_name, xmls) do
    roots = Enum.map(xmls, &SweetXml.parse(&1, quiet: true, namespace_conformant: false))
    # document order (LR-41): an instruction's context is what precedes it
    # in its provision ("In section 10 …—", then "(a) …"); xmerl's `//` order
    # (each node's children in turn, kept until LR-41 for zero-diff) put a
    # later subsection's words before an earlier one's paragraphs
    els =
      Enum.flat_map(roots, fn root ->
        Enum.filter([root | Xml.descendants(root)], &Xml.attr_or_nil(&1, :id))
      end)

    ids = Enum.map(els, &id/1)

    %__MODULE__{
      law_name: law_name,
      type: law_name |> String.split("_") |> Enum.at(1),
      enactment_date: Enum.find_value(roots, &enactment/1),
      ids: ids,
      pos: ids |> Enum.with_index() |> Map.new(),
      elements: Map.new(Enum.zip(ids, els)),
      titles: titles(roots),
      roots: roots
    }
  end

  @doc "The element with this id; nil when not held."
  @spec element(t(), String.t()) :: tuple() | nil
  def element(%__MODULE__{elements: els}, id), do: els[id]

  @doc "The held ids from `first` up to (not including) `id`, in document order."
  @spec between(t(), String.t(), String.t()) :: [String.t()]
  def between(%__MODULE__{pos: pos, ids: ids}, first, id) do
    case {pos[first], pos[id]} do
      {a, b} when is_integer(a) and is_integer(b) and a < b -> Enum.slice(ids, a, b - a)
      _ -> []
    end
  end

  @doc "The title of the nearest container over the element (its own title for a container)."
  @spec title(t(), String.t()) :: String.t() | nil
  def title(%__MODULE__{titles: titles}, id), do: titles[id]

  @doc "An element's text in document order (XPath `//text()` isn't), whitespace squashed."
  @spec text(tuple()) :: String.t()
  def text(el), do: el |> lines() |> Enum.join(" ")

  @doc "An element's text in document order, one entry per line (`<br/>`, `Para`, `Text` break)."
  @spec lines(tuple()) :: [String.t()]
  def lines(el) do
    el
    |> walk([[]])
    |> Enum.map(
      &(&1
        |> Enum.reverse()
        |> Enum.join()
        |> String.replace(~r/\s+/u, " ")
        |> String.trim())
    )
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  defp walk({:xmlText, _, _, _, value, _}, [line | rest]), do: [[to_string(value) | line] | rest]

  # by local name: some documents prefix their elements ("leg:Para" in
  # EReA 1999 Sch 9's repeals table cells, AR-13)
  defp walk({:xmlElement, name, _, _, _, _, _, _, children, _, _, _}, acc) do
    case local(name) do
      "br" -> [[] | acc]
      # a paragraph or text block starts a new line
      l when l in ["Para", "Text"] -> Enum.reduce(children, [[] | acc], &walk/2)
      _ -> Enum.reduce(children, acc, &walk/2)
    end
  end

  defp walk(_node, acc), do: acc

  defp local(name), do: name |> Atom.to_string() |> String.split(":") |> List.last()

  defp id(el), do: Xml.attr(el, :id)

  defp enactment(root) do
    case root |> xpath(~x"//*[local-name()='EnactmentDate']/@Date"s) |> to_string() do
      "" -> nil
      d -> Date.from_iso8601!(d)
    end
  end

  # each id → the title of its deepest titled container
  defp titles(roots) do
    roots
    |> Enum.flat_map(fn root ->
      for el <-
            xpath(
              root,
              ~x"//*[self::P1group or self::Pblock or self::PsubBlock or self::Part or self::Chapter or self::Schedule]"l
            ) do
        # xpath kept: its union orders text nodes by term order, which the
        # titles' text depends on (LR-31: "No. The Pastoral Measure 1983")
        title =
          el
          |> xpath(~x"./Title//text() | ./TitleBlock/Title//text()"ls)
          |> Enum.join()
          |> String.trim()

        {depth(el), title, el}
      end
    end)
    |> Enum.reject(fn {_, title, _} -> title == "" end)
    |> Enum.sort_by(&elem(&1, 0))
    |> Enum.reduce(%{}, fn {_, title, el}, acc ->
      ids = for d <- [el | Xml.descendants(el)], v = Xml.attr_or_nil(d, :id), v != nil, do: v
      Enum.reduce(ids, acc, &Map.put(&2, &1, title))
    end)
  end

  defp depth(el), do: el |> elem(5) |> length()
end
