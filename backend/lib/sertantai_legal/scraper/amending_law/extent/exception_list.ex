defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ExceptionList do
  @moduledoc """
  A default stated with the provisions excepted from it: "this Act does not
  extend to P, except …". The provisions excepted extend to P too (CV-S05
  round 13, S1: found by the CV-S05d census, which showed these items
  dropped in 13 laws). Every wording of it:

  - "This Act, except— (a) …; (b) …, does not extend to Northern Ireland"
    (HSWA s.84(1)); "This Act, except section 88, does not extend to …";
    "This Act, apart from sections 82 and 83, does not extend to …";
    "This Act, except this section and the following provisions, namely— …,
    does not extend to …" (Gas Act 1986 s.68(6));
  - "This Act, except for the following provisions, shall not extend to
    Northern Ireland, that is to say, this section and— (a) …" (1988/19
    s.34);
  - "Except for the following provisions, that is to say— (a) …, this Act
    does not extend to Northern Ireland" (1972/62 s.27); "Except for section
    8, this Act does not extend to Northern Ireland" (1991/65 s.10);
  - "This Act does not extend to Scotland, with the exception of— (a) …"
    (1996/25 s.79);
  - two in one sentence: "This Act, except section 88, does not extend to
    Northern Ireland and, except section 86 and Schedule 3, does not extend
    to Scotland" (1973/26 s.89).

  Each item is read as a list item (`ListItems`): its plain pieces extend
  there; a qualified item or piece ("… so far as …", "so much of …") keeps
  the default (round 6 design, HSWA s.84(1)(a)); "except as provided by
  section 189" is a reference, no item. Never a commencement's "This Act,
  except— (a) …, shall come into force" (2002/30 s.108(2), round 9 NEW-1).
  Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Forms, ListItems, Places, Units}
  alias SertantaiLegal.Scraper.Territory

  @place_list Places.place_list()
  @not_extend "(?:does|do|shall)\\s+not\\s+extend\\s+to\\s+(?<places>(?>#{@place_list}))"
  @following "(?:the\\s+following\\s+provisions\\s*,?\\s*(?:namely|that\\s+is\\s+to\\s+say)?\\s*,?\\s*)?"
  # items never run on into a commencement or a later subsection
  @items "(?<items>(?:(?!(?-i:\\.\\s*\\d+[A-Z]?\\s+[A-Z(]))(?!\\bcome\\s+into\\s+force\\b)(?!\\bnot\\s+extend\\b).)+?)"

  @forms [
    # "This Act, except for the following provisions, shall not extend to
    # Northern Ireland, that is to say, this section and— …"
    Regex.compile!(
      "#{Forms.subject()},\\s*(?:except|apart\\s+from)\\s+(?:for\\s+)?the\\s+following\\s+provisions\\s*,\\s*#{@not_extend}\\s*,?\\s*(?:namely|that\\s+is\\s+to\\s+say)\\s*,?\\s*[—–:]?\\s*#{@items}\\s*\\.?\\s*$",
      "isu"
    ),
    # "This Act, except— …, does not extend to …"; "This Act, except section
    # 88, does not extend to …"
    Regex.compile!(
      "#{Forms.subject()},\\s*(?:except|apart\\s+from)\\s*(?:for\\s*)?(?<self>this\\s+section\\s+and\\s+)?#{@following}[—–:]?\\s*#{@items},?\\s*#{@not_extend}",
      "isu"
    ),
    # "Except for the following provisions, that is to say— …, this Act does
    # not extend to …"; "Except for section 8, this Act does not extend …"
    Regex.compile!(
      "^\\s*(?:\\(\\w+\\)\\s*)?(?:Except|Apart\\s+from)\\s+(?:for\\s+)?#{@following}[—–:]?\\s*#{@items},?\\s*#{Forms.subject()}\\s+#{@not_extend}",
      "isu"
    ),
    # "This Act does not extend to Scotland, with the exception of— …"
    Regex.compile!(
      "#{Forms.subject()}\\s+#{@not_extend}\\s*,?\\s*(?:with\\s+the\\s+exception\\s+of|except(?:\\s+for)?)\\s*[—–:]\\s*(?<items>[^.]+)",
      "isu"
    )
  ]

  # "… does not extend to Northern Ireland and, except section 86 and
  # Schedule 3, does not extend to Scotland"
  @and_except Regex.compile!(
                "^\\s*and\\s*,?\\s*(?:except|apart\\s+from)\\s+(?:for\\s+)?#{@items},\\s*#{@not_extend}",
                "isu"
              )

  @type statement :: %{items: String.t(), places: String.t(), self: boolean()}

  @doc "Each exception statement the clause makes, in order; [] when none."
  @spec statements(String.t()) :: [statement()]
  def statements(clause) do
    # (each sentence of the clause on its own, repealed words' dots out: "(2)
    # Except for section 8, this Act does not extend …" is no clause's
    # start, 1991/65 s.10; ". . ." no sentence's end, 1972/62 s.27)
    clause
    # (a subsection's number runs into the sentence before it: "…
    # dwellings.3 For the purposes …")
    |> String.split(
      ~r/(?<=[.;:])\s+(?=(?:\(\d+[A-Z]?\)\s*)?[A-Z])|\s+(?=\(\d+[A-Z]?\)\s+[A-Z])|(?<=\.)(?=\d+[A-Z]?\s+[A-Z])/u
    )
    |> Enum.flat_map(fn sentence ->
      sentence = Units.no_dots(sentence)
      sentence_statements(sentence) ++ mentioned(sentence, Units.no_dots(clause))
    end)
  end

  # "With the exception of the provisions mentioned in subsection (6), this
  # Act does not extend to Northern Ireland. (6) Those provisions are— (a)
  # …; (e) this section." (ukpga 1989/38 s.30, CV-S05 seed 20): the items
  # are another subsection's
  @mentioned Regex.compile!(
               "^\\s*(?:\\(\\d+[A-Z]?\\)\\s*|\\d+[A-Z]?\\s+)?(?:With\\s+the\\s+exception\\s+of|Except\\s+for|Apart\\s+from)\\s+the\\s+provisions\\s+(?:mentioned|specified|listed)\\s+in\\s+subsection\\s+\\((?<sub>\\d+[A-Z]?)\\)\\s*,\\s*#{Forms.subject()}\\s+#{@not_extend}",
               "isu"
             )

  defp mentioned(sentence, clause) do
    with %{"sub" => sub} = m <- Regex.named_captures(@mentioned, sentence),
         [_, items] <-
           Regex.run(
             Regex.compile!(
               "(?:^|\\s|\\.)\\(?#{sub}\\)?\\s+(?:Those|These|The)\\s+provisions\\s+(?:are|referred\\s+to\\s+in\\s+subsection\\s+\\(\\w+\\)\\s+are)\\s*[—–:]\\s*(.+?)(?:\\.\\s*(?:\\(?\\d+[A-Z]?\\)?\\s+[A-Z]|$)|$)",
               "su"
             ),
             clause
           ) do
      [%{items: items, places: Places.places(m["places"]), self: false}]
    else
      _ -> []
    end
  end

  defp sentence_statements(sentence) do
    sentence = Regex.replace(~r/^\s*(?:\(\d+[A-Z]?\)|\d+[A-Z]?(?=\s+[A-Z]))\s*/u, sentence, "")

    Enum.find_value(@forms, [], fn form ->
      case Regex.run(form, sentence, return: :index, capture: :all) do
        nil ->
          nil

        [{at, len} | _] ->
          m = Regex.named_captures(form, sentence)
          rest = binary_part(sentence, at + len, byte_size(sentence) - at - len)
          [statement(m) | more(rest)]
      end
    end)
  end

  defp more(rest) do
    case Regex.named_captures(@and_except, rest) do
      nil -> []
      m -> [statement(m)]
    end
  end

  # (the clause's own section leading the items: "…, that is to say, this
  # section and— (a) …" (ukpga 1988/19 s.34), "Except for this section and
  # any amendment or repeal …" (ukpga 1995/25 s.125): CV-S05 census run-05
  # R10)
  defp statement(m) do
    lead = ~r/^\s*this\s+section\s*(?:,|;|\band\b)\s*/iu
    items = m["items"]

    %{
      items: String.replace(items, lead, "", global: false),
      places: Places.places(m["places"]),
      self: (m["self"] || "") != "" or items =~ lead
    }
  end

  @doc "Whether the clause makes an exception statement."
  @spec match?(String.t()) :: boolean()
  def match?(clause), do: statements(clause) != []

  @doc """
  The law's default the statements leave: the United Kingdom less every
  place they name, and every other place the clause says the law does not
  extend to ("This Act, except section 4(5) to (8) …, does not extend to
  Northern Ireland. … but except as aforesaid this Act does not extend to
  Scotland": E+W, 1973/37 s.40).
  """
  @spec default(String.t()) :: String.t() | nil
  def default(clause) do
    case statements(clause) do
      [] ->
        nil

      st ->
        others = for m <- Regex.scan(Forms.not_extends(), clause), do: Places.places(List.last(m))

        Enum.reduce(
          Enum.map(st, & &1.places) ++ others,
          "E+W+S+NI",
          &Territory.subtract(&2, &1)
        )
    end
  end

  @doc "The provisions each statement excepts, as `{:also, place, refs}`."
  @spec lists(String.t(), String.t() | nil, Doc.t()) :: [{:also, String.t(), [String.t()]}]
  def lists(clause, clause_ref, doc) do
    for st <- statements(clause),
        refs = refs(st, clause_ref, doc),
        refs != [],
        do: {:also, st.places, refs}
  end

  # each item, plainly; "this section" the clause's own provision
  defp refs(st, clause_ref, doc) do
    items =
      st.items
      # ("so much of Schedule 1 as amends …": withheld, keeps the default)
      |> String.split(~r/;|,(?=\s*(?:and\s*)?[a-hj-uwyz]\s)/u)
      # (never one leading a sub-list, "the repeal … of— i …", 1994/21 s.68)
      |> Enum.reject(&(&1 =~ ~r/\bso\s+much\s+of\b|[—–]\s*\S/iu))

    self = if st.self and clause_ref, do: [clause_ref], else: []

    (self ++ Enum.flat_map(items, &item_refs(&1, clause_ref, doc)))
    |> Enum.uniq()
  end

  # (a companion before a qualifier is plain only where the qualifier's
  # object points back to it, "paragraphs 1 to 3 … of Schedule 5 and
  # section 17(1) and (2) so far as relating to those paragraphs"; else the
  # qualifier may be both's, "Schedule 6 and section 17(5) so far as
  # relating to the repeals of …": the item keeps the default, 1995/45 s.18)
  @qualifier ~r/\b(?:so\s+far\s+as|in\s+so\s+far|insofar|to\s+the\s+extent)\b/iu
  @points_back ~r/\b(?:so\s+far\s+as|in\s+so\s+far\s+as|insofar\s+as)\s+(?:it\s+|they\s+)?relat\w*\s+(?:to\s+)?(?:th(?:ose|at|ereto|em)\b|it\b)|\band\s*,\s*(?:so\s+far|in\s+so\s+far|insofar)\s+as\b/iu

  # ("paragraphs 7, 29 and 30 of Schedule 3 and, so far as relating to
  # those paragraphs, section 59(1)": whole, its plain part read, 1990/16
  # s.60)
  defp item_refs(item, clause_ref, doc) do
    if item =~ ~r/\band\s*,\s*(?:so\s+far|in\s+so\s+far|insofar)\s+as\b/iu,
      do: ListItems.refs(item, clause_ref, doc),
      else: piece_refs(item, clause_ref, doc)
  end

  defp piece_refs(item, clause_ref, doc) do
    # (each piece after a comma on its own: "paragraphs 6 and 7 of
    # Schedule 3, and paragraph 8 of Schedule 3 so far as it relates to …",
    # 1996/25 s.79)
    item
    |> String.split(
      ~r/,\s*(?:and\s+)?(?=(?:paragraphs?|sub-?paragraphs?|sections?|subsections?|Schedules?|Parts?|Chapters?|regulations?|articles?|this)\b)/iu
    )
    |> Enum.flat_map(fn piece ->
      if piece =~ @qualifier and not (piece =~ @points_back),
        do: [],
        else: ListItems.refs(piece, clause_ref, doc)
    end)
  end
end
