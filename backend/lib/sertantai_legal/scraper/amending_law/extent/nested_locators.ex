defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.NestedLocators do
  @moduledoc """
  A list item that locates sub-items in one provision, each sub-item
  rewritten whole (CV-S05 census run-05 R5, uksi 2017/1012 reg.2):

  - "e in regulation 70 (grant of planning permission)— i paragraph
    (1)(e)(ii) and (iii) (…); ii …" → "regulation 70(1)(e)(ii) and (iii)
    (…)";
  - "f in regulation 71 (…), in paragraph (4)— i sub-paragraph (b); …" →
    "regulation 71(4)(b)";
  - "m in Part 1 of Schedule 6 (…)— i sub-paragraphs (2) and (4) of
    paragraph 8 (…)" → "… of paragraph 8 of Schedule 6 (…)".

  Read before, a sub-item was read against the clause's own provision, and
  the locator as the whole provision. The sub-items are the roman ones in
  sequence after the dash ("i", "ii", "iii" …); any other label ends them.
  A qualified sub-item keeps its qualifier (withheld as before). Pure.
  """

  @label "^\\s*(?:and\\s*)?\\(?(?<label>z?[a-z]{1,2}\\d{0,2}|[ivx]{2,4})\\)?\\s+"
  @desc "(?:\\s*\\((?:[^()]|\\([^()]*\\))*\\))?"
  @head Regex.compile!(
          "#{@label}in\\s+(?<owner>(?<kw>regulation|section|article|rule)\\s+(?<n>\\d+[A-Z]*)|(?:Part\\s+[\\dIVXLC]+[A-Z]*\\s+of\\s+)?Schedule\\s+(?<sch>\\d+[A-Z]*))#{@desc}(?:\\s*,\\s*in\\s+(?:sub-)?paragraph\\s+(?<sub>\\(\\w+\\)))?\\s*[—–]\\s*(?:\\(?i\\)?\\s+)(?<rest>.+)$",
          "isu"
        )
  @roman ~w(i ii iii iv v vi vii viii ix x)

  # "in Part 6 of Schedule 8, the repeals in …"; "in Schedule 11, the
  # amendments to …" (R6)
  @some_of Regex.compile!(
             "#{@label}?in\\s+(?<loc>(?:Part\\s+[\\dIVXLC]+[A-Z]*\\s+of\\s+)?Schedule\\s+\\d+[A-Z]*)\\s*,\\s*the\\s+(?:amendments?|repeals?|revocations?)\\b",
             "iu"
           )

  @doc """
  The locator of an item naming only some of what it holds ("in Part 6 of
  Schedule 8, the repeals in the … Act 1994 and in the … Act 1998": ukpga
  2001/24 s.128; "in Schedule 11, the amendments to …": ukpga 2022/32
  s.207, CV-S05 census run-05 R6), its bound to withhold; nil otherwise.
  """
  @spec some_of(String.t()) :: String.t() | nil
  def some_of(item) do
    case Regex.named_captures(@some_of, item) do
      %{"loc" => loc} -> loc
      nil -> nil
    end
  end

  @doc "The list's pieces, each sub-item of a nested locator rewritten with its provision."
  @spec expand([String.t()]) :: [String.t()]
  def expand(pieces) do
    {out, _} =
      Enum.map_reduce(pieces, nil, fn piece, ctx ->
        case Regex.named_captures(@head, piece) do
          %{} = m -> {rewrite(m["rest"], m), {m, 1}}
          nil -> sub_item(piece, ctx)
        end
      end)

    out
  end

  # a sub-item while its locator holds: the next roman label in sequence
  defp sub_item(piece, {m, at}) do
    case Regex.run(Regex.compile!(@label, "u"), piece, capture: :all_names) do
      [label] ->
        if String.downcase(label) == Enum.at(@roman, at) do
          {rewrite(String.replace(piece, Regex.compile!(@label, "u"), "", global: false), m),
           {m, at + 1}}
        else
          {piece, nil}
        end

      _ ->
        # ("…; and paragraph (3) in so far as …": the locator's provision's
        # own paragraph, after its sub-items)
        if piece =~ ~r/^\s*and\s+(?:sub-)?paragraphs?\s+\(/iu,
          do: {rewrite(String.replace(piece, ~r/^\s*and\s+/iu, ""), %{m | "sub" => ""}), {m, at}},
          else: {piece, nil}
    end
  end

  defp sub_item(piece, nil), do: {piece, nil}

  # "paragraph (1)(e)(ii) and (iii)" in regulation 70 → "regulation
  # 70(1)(e)(ii) and (iii)"; in a Schedule, "… of paragraph 8" → "… of
  # paragraph 8 of Schedule 6"; a describing bracket out ("(deemed grant …
  # under section 5(1) of the Pipe-lines Act 1962)": never another law's
  # item)
  defp rewrite(text, m), do: text |> undescribed() |> owned(m)

  defp owned(text, %{"kw" => kw} = m) when kw != "" do
    Regex.replace(
      ~r/^\s*(?:sub-)?paragraphs?\s+(?=\()/iu,
      text,
      "#{kw} #{m["n"]}#{m["sub"]}",
      global: false
    )
  end

  defp owned(text, m) do
    Regex.replace(
      ~r/\b(paragraphs?\s+\d+[A-Z]*(?:\([^()\s]*\))*)(?!\s+of\s+Schedule)/iu,
      text,
      "\\1 of Schedule #{m["sch"]}",
      global: false
    )
  end

  defp undescribed(text),
    do: Regex.replace(~r/\s*\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u, text, "")
end
