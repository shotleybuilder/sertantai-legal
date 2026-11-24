defmodule SertantaiLegal.Scraper.Commencement.Review.DifferencePatterns do
  @moduledoc """
  The feed differences' one-law wordings as patterns, to be looked for in
  every law and order (RULES `feed-differences-are-patterns-by-feed-coverage`,
  Jason 2026-11-23). A wording held where the feed holds no commencement is
  the Reader's to fix; one held only where the feed speaks is a known limit,
  and the feed is used.

  Each pattern names the `feed_differences.json` entries it judges. It
  matches a law's own rows (`own/1`), an order's articles and Schedule table
  rows (`order/1`), or the orders an Act is commenced by (`territory_orders/1`).
  Pure.
  """

  @type hit :: {String.t(), String.t()}

  @cif ~r/\b(?:comes?|came)\s+into\s+(?:force|operation)\b/i
  @dots ~r/^[\s.…]*(?:\.\s*){3,}[\s.…]*$/u
  @territory "(?:England|Wales|Scotland|Northern\\s+Ireland)"

  @entries %{
    "excepted-paragraph-omitted" => [
      "differ | own dated by clause_date | own earlier @ UK_nisr_2011_127"
    ],
    "whole-law-purpose-stages" => [
      "differ | own dated by clause_date | own earlier @ UK_uksi_2016_359",
      "differ | own dated by clause_date | own earlier @ UK_wsi_2016_359"
    ],
    "alternative-days-whichever" => [
      "differ | own dated by clause_made_relative | own earlier @ UK_uksi_2020_1265"
    ],
    "provision-tied-to-another-law" => [
      "feed_only | own by_order by provision_by_order | feed full @ UK_uksi_2006_641"
    ],
    "table-row-long-exception" => [
      "differ | own dated by order_schedule | own earlier @ UK_nisi_2006_3336",
      "differ | own dated by order_schedule | own later @ UK_nisi_2006_3336",
      "feed_only | own by_order by by_order | feed full @ UK_nisi_2006_3336",
      "feed_only | own by_order_partly by by_order | feed full @ UK_nisi_2006_3336"
    ],
    "application-with-exception" => [
      "feed_only | own by_order_partly by by_order | feed full @ UK_ukpga_2003_37"
    ],
    "subject-to-territory-paragraph" => [
      "feed_only | own by_order_partly by provision_by_order | feed full @ UK_ukpga_2003_33"
    ],
    "one-order-per-territory" => [
      "feed_partial_only | own staged by order_date | first differs @ UK_ukpga_2003_33"
    ]
  }

  @doc "The patterns' names."
  @spec names() :: [String.t()]
  def names, do: @entries |> Map.keys() |> Enum.sort()

  @doc "The `feed_differences.json` entries a pattern judges."
  @spec entries(String.t()) :: [String.t()]
  def entries(name), do: Map.fetch!(@entries, name)

  # where the Reader reads the law's words right and the difference is the
  # feed's way of staging it: no misread, wherever it is held (2003 c.33:
  # ours the law's earlier order, Wales's; the feed's first stage England's)
  @yardstick ["one-order-per-territory"]

  @doc """
  A pattern's verdict from its laws by coverage: held by any law the feed
  is silent on, the Reader's (`:fix`); else `:known` (the feed used). A
  yardstick pattern, where the Reader reads the law right, is `:yardstick`
  wherever it is held.
  """
  @spec verdict(String.t(), %{covered: non_neg_integer(), none: non_neg_integer()}) ::
          :fix | :known | :yardstick
  def verdict(name, _counts) when name in @yardstick, do: :yardstick
  def verdict(_name, %{none: n}) when n > 0, do: :fix
  def verdict(_name, _counts), do: :known

  @rule "RULES `feed-differences-are-patterns-by-feed-coverage`; Jason 2026-11-24, Decision 1 (a)"

  @doc """
  A judged entry's new status from its pattern's verdict and law counts,
  keeping the old status's own words (after its last "): ").
  """
  @spec status(String.t(), :fix | :known | :yardstick, map(), String.t()) :: String.t()
  def status(name, verdict, counts, old) do
    "#{head(verdict, name, counts)}: #{detail(old)}"
  end

  defp head(:fix, name, c),
    do:
      "fix: the pattern #{name} is held where the feed holds no commencement (#{c.none} laws; #{c.covered} where it does), so the Reader is the source and reads it (#{@rule})"

  defp head(:known, name, c),
    do:
      "known: the pattern #{name} is held only where the feed holds the commencement (#{c.covered} laws), so the feed is the date (#{@rule})"

  defp head(:yardstick, name, c),
    do:
      "known: a yardstick difference, the pattern #{name} (#{c.covered + c.none} laws): the Reader reads the law's words; the feed stages it otherwise (#{@rule})"

  defp detail(old), do: old |> String.split("): ") |> List.last()

  # ── a law's own rows ────────────────────────────────────────────────

  @doc "A law's own rows (`id`, `text`, ids without the law) → each pattern hit, with the row (or provision) it is on."
  @spec own([%{id: String.t(), text: String.t() | nil}]) :: [hit()]
  def own(rows) do
    rows = Enum.map(rows, &%{&1 | text: &1.text || ""})
    by_id = Map.new(rows, &{&1.id, &1.text})

    row_hits =
      for r <- rows,
          r.text =~ @cif,
          name <- row_patterns(r, by_id),
          do: {name, r.id}

    row_hits ++ staged_laws(rows)
  end

  defp row_patterns(r, by_id) do
    [
      {"excepted-paragraph-omitted", excepted_omitted?(r, by_id)},
      {"alternative-days-whichever", whichever?(r.text)},
      {"provision-tied-to-another-law", provision_tied?(r.text)}
    ]
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  # "except as provided in paragraphs (2), (3) and (4) shall come into
  # operation on …", (4) now ". . . ." in the revised text (NISR 2011/127)
  @excepted ~r/\bexcept\s+as\s+(?:otherwise\s+)?provided\s+(?:in|by)\s+paragraphs?\s+((?:\(\w+\)(?:\s*,\s*|\s+and\s+|\s+to\s+)?)+)/i

  defp excepted_omitted?(r, by_id) do
    case Regex.run(@excepted, r.text) do
      [_, list] ->
        provision = provision(r.id)

        ~r/\((\w+)\)/
        |> Regex.scan(list, capture: :all_but_first)
        |> Enum.any?(fn [n] -> (by_id["#{provision}(#{n})"] || "") =~ @dots end)

      nil ->
        false
    end
  end

  # "… come into force— (a) …; or (b) …, whichever is later" (SI 2020/1265 art.2(2))
  # (a commencement statement opening its days' list, never a duty
  # counting from one: "need not comply … until …, whichever occurs first"
  # (SI 2025/1298 reg.10(4)), nor words a quote inserts)
  defp whichever?(text),
    do:
      text =~ ~r/\binto\s+(?:force|operation)\s*(?:on\s*)?[—–:]/u and
        not String.contains?(text, "«") and
        text =~
          ~r/\bwhichever\s+(?:is|occurs|comes|falls|first\s+occurs)\s+(?:the\s+)?(?:later|earlier|last|first|latest|earliest)\b/i

  # "Regulation 15 shall come into force on the date on which section 7(3)
  # of the Water Act 2003 comes into force" (SI 2006/641 reg.1(2))
  # … or the whole law tied to another law ("These Regulations come into
  # force on the day on which the Biodiversity Gain Site Register Regulations
  # 2024 come into force": SI 2024/46), the other law named in full or short
  # ("section 83 of the 2022 Act": SI 2023/907)
  @other_law "(?:the\\s+)?(?:\\d{4}\\s+(?:Act|Order|Regulations)\\b|(?:[A-Z(][\\w()',’-]*\\s+(?:(?:and|of|for|the|in|on|to|with)\\s+)*){1,14}(?:Act|Order|Regulations|Measure|Rules)(?:\\s+\\(Northern\\s+Ireland\\))?\\s+\\d{4}\\b)"
  @tied Regex.compile!(
          "\\binto\\s+(?:force|operation)\\s+(?:on\\s+the\\s+(?:date|day)\\s+on\\s+which|at\\s+the\\s+same\\s+time\\s+as|immediately\\s+(?:after|before))\\s+" <>
            "(?:the\\s+coming\\s+into\\s+(?:force|operation)\\s+of\\s+)?" <>
            "(?:(?:section|regulation|article|paragraph|rule|Part|Schedule|Chapter)s?\\s+[\\w().]+(?:\\s*(?:,|and|to)\\s*[\\w().]+)*\\s+of\\s+)?" <>
            "(?!this\\b|these\\b|th(?:at|is)\\s+(?:Act|Part|Order)\\b)" <> @other_law
        )

  # a provision tied, never the whole law: that is `LawStart`'s
  # `:tied_to_other_law`, read ("This Order … shall come into force on the
  # day on which section 11 of the Fire (Scotland) Act 2005 comes into
  # force": SSI 2005/342)
  @whole_subject ~r/(?:\b(?:these\s+Regulations|this\s+Order|this\s+Act|these\s+Rules|this\s+Measure|it)|\band)\s+(?:shall\s+|is\s+to\s+|are\s+to\s+)?(?:comes?|come)\s*$/i

  defp provision_tied?(text) do
    case Regex.run(@tied, text, return: :index) do
      [{at, _} | _] ->
        subject = text |> binary_part(0, at) |> last_sentence()
        not (subject =~ @whole_subject)

      nil ->
        false
    end
  end

  defp last_sentence(text), do: text |> String.split(~r/(?<=[.;])\s+/) |> List.last()

  # the whole law brought in on two days, one of them for a purpose ("these
  # Regulations come into force on 15 March 2020 in relation to any
  # container …": SI 2016/359 reg.1(3)–(5))
  @whole ~r/\b(?:these\s+Regulations|this\s+Order|this\s+Act|these\s+Rules|this\s+Measure)\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\s+on\b/i
  @purpose ~r/\b(?:in\s+relation\s+to|for\s+the\s+purposes?\s+of|in\s+so\s+far\s+as|so\s+far\s+as)\b/i

  defp staged_laws(rows) do
    rows
    |> Enum.filter(&(&1.text =~ @whole))
    |> Enum.group_by(&provision(&1.id))
    |> Enum.filter(fn {_p, rs} -> length(rs) >= 2 and Enum.any?(rs, &purpose?/1) end)
    |> Enum.map(fn {p, _rs} -> {"whole-law-purpose-stages", p} end)
    |> Enum.sort()
  end

  # ("In so far as they are not already in force, these Regulations come
  # into force on 6th April 2026" completes the law: SI 2026/15 reg.1(3))
  defp purpose?(r),
    do: r.text =~ @purpose and not (r.text =~ ~r/\bnot\s+(?:already|previously)\s+in\s+force\b/i)

  defp provision(id), do: id |> String.split("(", parts: 2) |> hd()

  # ── an order's articles and table rows ──────────────────────────────

  @doc """
  An order's units (`kind`: "article" for each article's whole text,
  "table" for a Schedule table row, as `OrderPatterns.units/1` gives them)
  → each pattern hit, with the unit's id.
  """
  @spec order([%{kind: String.t(), id: String.t(), text: String.t()}]) :: [hit()]
  def order(units) do
    for u <- units, name <- unit_patterns(u), do: {name, u.id}
  end

  defp unit_patterns(%{kind: "article", text: text}) do
    [
      {"application-with-exception", application_exception?(text)},
      {"subject-to-territory-paragraph", territory_paragraph?(text)}
    ]
    |> Enum.filter(&elem(&1, 1))
    |> Enum.map(&elem(&1, 0))
  end

  defp unit_patterns(%{kind: "table", text: text}),
    do: if(long_exception?(text), do: ["table-row-long-exception"], else: [])

  defp unit_patterns(_unit), do: []

  # "This Order applies in relation to England only except article 2(d)
  # which extends to Scotland only" (SI 2009/359 art.1(2))
  defp application_exception?(text),
    do:
      text =~
        Regex.compile!(
          "\\bThis\\s+Order\\s+(?:applies|extends)\\s+(?:in\\s+relation\\s+)?to\\s+#{@territory}(?:\\s+only)?,?\\s+except\\s+(?:article|paragraph|regulation)",
          "i"
        )

  # "(1) Subject to paragraph (2) Sections 4, 5, 9, 10, 19 and 35(a) and (c)
  # … come into force on 25 June 2004. (2) Sections 4, 5, 9, 10 and 35(a)
  # are brought into force in relation to Wales" (WSI 2004/1488 art.2): the
  # narrowing paragraph names no day of its own
  defp territory_paragraph?(text) do
    text =~ ~r/\bSubject\s+to\s+paragraph\s+\(?\d+\)?/i and
      text
      |> String.split(~r/(?<=[.;])\s+/)
      |> Enum.any?(&territory_only?/1)
  end

  defp territory_only?(sentence),
    do:
      sentence =~
        Regex.compile!(
          "\\b(?:brought|comes?|come)\\s+into\\s+(?:force|operation)\\s+(?:only\\s+)?in\\s+relation\\s+to\\s+#{@territory}\\b",
          "i"
        ) and not (sentence =~ ~r/\b\d{1,2}(?:st|nd|rd|th)?\s+[A-Z][a-z]+\s+\d{4}\b/)

  # a limit opening a list of its own ("… in so far as it relates to:
  # Article 9(1) and 9(2) of the 1999 Order; …": NISR 2007/194 Sch.1), or an
  # exception with more of the list after it ("Section 83(1) (except in so
  # far as it relates to section 24 of the Act), (3) …, (6) and (7)": SI
  # 1964/191 Sch.1 Pt III; "… except paragraphs 1(1)(b), 2(1)(b), 2(3)(a)
  # and 3 of that Schedule; and Articles 10 and 13": NISR 2007/194 Sch.1)
  @list_limit ~r/\bin\s+so\s+far\s+as\s+it\s+relates\s+to\s*:/i
  @mid_list ~r/\bexcept\b[^;|“”«»]*?(?:\)\s*,\s*\(\d+[A-Z]*\)|;\s+(?:and\s+)?(?:sections?|articles?|paragraphs?|regulations?|schedules?|parts?)\s+\d)/i

  defp long_exception?(text), do: text =~ @list_limit or text =~ @mid_list

  # ── the orders an Act is commenced by ───────────────────────────────

  @doc """
  Acts commenced by one order per territory ("(England) Order", "(Wales)
  Order"): `%{act => [{order, title}]}` → each hit, with its orders. The
  feed's first stage can then be one territory's order and ours another's
  (2003 c.33: SI 2004/3181 for England, WSI 2004/1488 for Wales).
  """
  @spec territory_orders(%{String.t() => [{String.t(), String.t() | nil}]}) ::
          [{String.t(), String.t(), [String.t()]}]
  def territory_orders(titles) do
    for {act, orders} <- Enum.sort(titles),
        by_place = territorial(orders),
        map_size(by_place) >= 2,
        do:
          {"one-order-per-territory", act,
           by_place |> Map.values() |> List.flatten() |> Enum.sort()}
  end

  defp territorial(orders) do
    orders
    |> Enum.flat_map(fn {order, title} ->
      case Regex.run(
             Regex.compile!("\\((#{@territory})\\)\\s+(?:Order|Regulations)", "i"),
             title || ""
           ) do
        [_, place] -> [{String.downcase(place), order}]
        nil -> []
      end
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end
end
