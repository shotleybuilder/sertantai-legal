defmodule SertantaiLegal.Scraper.AmendingLaw.Doc do
  @moduledoc """
  An amending law's CLML, parsed once (lat-refactor LR-08): its documents
  (body and Schedules) as one set of elements by id, in document order,
  with the title of the nearest container over each (a Part titled
  "Electricity Act 1989", a cross-heading) and the enactment date. The
  other `AmendingLaw` readers take this, never raw XML. Pure.
  """

  import SweetXml

  @enforce_keys [:law_name, :type]
  defstruct [:law_name, :type, :enactment_date, ids: [], elements: %{}, titles: %{}, roots: []]

  @type t :: %__MODULE__{
          law_name: String.t(),
          type: String.t(),
          enactment_date: Date.t() | nil,
          ids: [String.t()],
          elements: %{String.t() => tuple()},
          titles: %{String.t() => String.t()},
          roots: [tuple()]
        }

  @doc "Parse a law's documents (`xmls`: body, Schedules)."
  @spec new(String.t(), [String.t()]) :: t()
  def new(law_name, xmls) do
    roots = Enum.map(xmls, &SweetXml.parse(&1, quiet: true, namespace_conformant: false))
    els = Enum.flat_map(roots, &xpath(&1, ~x"//*[@id]"l))
    ids = Enum.map(els, &id/1)

    %__MODULE__{
      law_name: law_name,
      type: law_name |> String.split("_") |> Enum.at(1),
      enactment_date: Enum.find_value(roots, &enactment/1),
      ids: ids,
      elements: Map.new(Enum.zip(ids, els)),
      titles: titles(roots),
      roots: roots
    }
  end

  @doc "The element with this id; nil when not held."
  @spec element(t(), String.t()) :: tuple() | nil
  def element(%__MODULE__{elements: els}, id), do: els[id]

  @doc "The title of the nearest container over the element (its own title for a container)."
  @spec title(t(), String.t()) :: String.t() | nil
  def title(%__MODULE__{titles: titles}, id), do: titles[id]

  defp id(el), do: el |> xpath(~x"./@id"s) |> to_string()

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
      ids = el |> xpath(~x"./descendant-or-self::*/@id"ls) |> Enum.map(&to_string/1)
      Enum.reduce(ids, acc, &Map.put(&2, &1, title))
    end)
  end

  defp depth(el), do: el |> elem(5) |> length()
end
