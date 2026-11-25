defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Patterns.Example do
  @moduledoc """
  The extent catalogue's example of a law and its pattern keys
  (`mix lat.extent_patterns`): the law flattened to what the reading needs —
  each top-level provision with extent or application words, whole, and
  the Parts and sections around them as empty shells in document order
  (`example/1`), read alone (`read/2`); and one sentence's key (`key/2`).
  The catalogue's own code, never the reading's: its edits stale no stored
  reading (`Extent.ReadVersion.Catalogue`; the Extent reader stamps
  session). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Patterns

  @doc "The pattern key of one sentence: its form and outcome as one key."
  @spec key(Patterns.form(), String.t()) :: String.t()
  def key(f, class) do
    flag = fn b, name -> if b, do: name, else: "-" end

    Enum.join(
      [
        f.kind,
        f.subject,
        f.verb,
        f.lead,
        "places:" <> f.places,
        flag.(f.only, "only"),
        flag.(f.also, "also"),
        class
      ],
      "|"
    )
  end

  @doc """
  An example: the law flattened to what `Extent.Reader.read/1` reads — each
  top-level provision speaking of extent or application, with its words,
  and the Parts, their Chapters and top-level sections (regulations, articles) as empty
  shells, all in document order — as XML.
  """
  @spec example(Doc.t()) :: String.t()
  def example(%Doc{} = doc) do
    words = Map.new(Patterns.provisions(doc), fn {id, _ref, text} -> {id, text} end)

    elements =
      for id <- doc.ids,
          {keep} =
            {Map.has_key?(words, id) and Patterns.words?(words[id]) and
               not Patterns.container?(doc, id)},
          shell?(id) or keep,
          do: element(doc, id, keep)

    body = [{:Body, [], elements}]

    [{:Legislation, [], [{:Primary, [], body}]}]
    |> :xmerl.export_simple(:xmerl_xml, prolog: [])
    |> :unicode.characters_to_binary()
  end

  # (a Part's Chapters too: "Chapter 1 of Part 3 … extends to …", CV-S05 NEW-A)
  defp shell?(id),
    do:
      id =~
        ~r/^(?:part-[^-]+(?:-chapter-[^-]+)?|(?:section|regulation|article|rule)-\d+[A-Z]*)$/

  defp element(_doc, id, false), do: {:P1, [id: to_charlist(id)], []}

  # the provision with its subsections, each whole (the units read)
  defp element(doc, id, true) do
    case Doc.children(doc, id) do
      [] ->
        {:P1, [id: to_charlist(id)], [text(doc, id)]}

      children ->
        {:P1, [id: to_charlist(id)],
         for(c <- children, do: {:P2, [id: to_charlist(c)], [text(doc, c)]})}
    end
  end

  defp text(doc, id),
    do: {:Text, [], [doc |> Doc.element(id) |> Doc.lines() |> Enum.join(" ") |> to_charlist()]}

  @doc "What the reader makes of an example (`example/1`'s XML) for `law`."
  @spec read(String.t(), String.t()) :: [{String.t(), String.t(), String.t()}]
  def read(law, xml), do: law |> Doc.new([xml]) |> Patterns.classes()
end
