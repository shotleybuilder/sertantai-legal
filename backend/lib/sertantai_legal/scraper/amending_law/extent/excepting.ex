defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Excepting do
  @moduledoc """
  A Part's extent with its exceptions listed after it (CV-S05 round 9,
  round 8 NEW-2; ERRA 2013 s.102):

  - "Part 3 extends to England and Wales, Scotland and Northern Ireland,
    except as follows— (a) paragraphs 15 to 44 … of Schedule 6 extend only
    to England and Wales and Scotland; (b) …";
  - "Part 2 extends only to England and Wales and Scotland, except that the
    following provisions of Part 2 extend also to Northern Ireland— (a)
    section 23(3); (b) …";
  - "This Part extends to … except that— (a) sections 92, 93 … extend only
    to England and Wales and Scotland; (b) …";
  - "Part 6 of this Act (nature and biodiversity) extends to England and
    Wales, except that— (a) the amendments made by Schedule 15 … have the
    same extent as …" (ukpga 2021/30 s.146, round 13 S7).

  The lead is read as a list for the Part's provisions (`:only` where it
  says "only", else `:named`), and only where every exception is read
  plainly: each a plain extent statement naming provisions, or (the
  "following provisions" form) a provision named. A qualified exception
  ("so far as …") leaves the sentence unread, its Part's bound withheld.
  The exceptions are read where they are stated (`Named`, `Lists`); one
  naming a Schedule paragraph outranks the Part its introducing section is
  in (`Lookup`). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Default, Parts, Places}

  @place_list Places.place_list()
  @part "(?:This\\s+Part|Parts?\\s+[\\dIVXL]+[A-Z]*(?:\\s*(?:,|and)\\s*[\\dIVXL]+[A-Z]*)*|Chapters?\\s+\\d+[A-Z]*\\s+of\\s+Part\\s+[\\dIVXL]+[A-Z]*)"
  @lead Regex.compile!(
          "^\\s*(?<subj>#{@part}(?:\\s+of\\s+this\\s+Act)?)(?:\\s*\\((?:[^()]|\\([^()]*\\))*\\))?\\s+(?:shall\\s+)?extends?\\s+(?<only>only\\s+)?to\\s+(?<places>(?>#{@place_list}))(?<only2>\\s+only)?\\s*,?\\s*except\\s+(?:as\\s+follows\\s*[—–]|that\\s*[—–]|(?<following>that\\s+the\\s+following\\s+provisions\\s+of\\s+#{@part}\\s+(?:shall\\s+)?extends?\\s+also\\s+to\\s+(?>#{@place_list})\\s*[—–]))(?<items>.+)$",
          "su"
        )
  @qualified ~r/\b(?:so\s+far|in\s*so\s*far|insofar|to\s+the\s+extent|except|which|subject\s+to|where|if)\b/iu

  @doc """
  The lead's list of `s` (in provision `ref`): `{kind, place, refs}` for
  the Part's provisions, or nil when `s` isn't this form or an exception
  isn't read plainly.
  """
  @spec lead(String.t(), String.t(), Doc.t()) :: {:only | :named, String.t(), [String.t()]} | nil
  def lead(s, ref, %Doc{} = doc) do
    with %{} = m <- Regex.named_captures(@lead, s),
         items when items != [] <- items(m["items"]),
         true <- Enum.all?(items, &plain?(&1, m["following"] != "", ref, doc.type)),
         [_ | _] = refs <- own(m, items, ref, doc) do
      kind = if m["only"] != "" or m["only2"] != "", do: :only, else: :named
      {kind, Places.places(m["places"]), refs}
    else
      _ -> nil
    end
  end

  @doc "The leads read from the unit sentences (`Units.unit_sentences/1`)."
  @spec leads([{String.t(), String.t()}], Doc.t()) :: [{atom(), String.t(), [String.t()]}]
  def leads(unit_sentences, doc) do
    for {ref, s} <- unit_sentences, l = lead(s, ref, doc), l != nil, uniq: true, do: l
  end

  # the Part's provisions, less those an exception sets ("This Part extends
  # to … except that— (a) sections 92, 93 … extend only to …": s.92 is
  # the exception's alone); the "following provisions … extend also" form
  # widens, so takes none out
  defp own(m, items, ref, doc) do
    part = Enum.uniq(RefList.parse(m["subj"], ref) ++ Parts.parts(m["subj"], doc, ref))

    excepted =
      if m["following"] != "", do: [], else: Enum.flat_map(items, &RefList.parse(&1, ref))

    Enum.reject(part, fn r -> Enum.any?(excepted, &(&1 == r or RefList.covers?(&1, r))) end)
  end

  # the lettered exceptions ("a …;b …;and c …")
  defp items(text) do
    text
    |> String.split(~r/(?:^|;)\s*(?:and\s*)?\(?[a-z]{1,2}\)?\s+/u)
    |> Enum.map(&(&1 |> String.trim() |> String.trim_trailing(".") |> String.trim()))
    |> Enum.reject(&(&1 == ""))
  end

  # a provision named ("section 23(3)"), or a plain extent statement
  # naming provisions ("paragraphs 52 to 68 … of Schedule 6 extend only to
  # England and Wales")
  defp plain?(item, following?, ref, type) do
    not (item =~ @qualified) and RefList.parse(item, ref) != [] and
      (following? or
         match?(
           {:list, k, _} when k in [:only, :named, :also, :not, :same],
           Default.statement(item, type)
         ))
  end
end
