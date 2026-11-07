defmodule SertantaiLegal.Scraper.Checks.ExtentShapes.Mine do
  @moduledoc """
  Extent shape mining (CV-S05c), ported from `mine.py` (#192): each
  catalogue sentence split into its lead and its lettered items, every
  reference, place, law title and description masked, and the masked
  shapes counted. `run/1` writes what `mine.py` wrote, byte for byte:
  `items.tsv`, `shapes.tsv` and `stats.json`. Pure.
  """

  alias SertantaiLegal.Scraper.Checks.PyCompat

  # lettered items as flattened from CLML: "—a the …;b …; andc …", ", butb"
  @mark ~r/(?:[;—–:]\s*(?:(?:and|or|but)\s?)?|,(?=[a-z]{1,2}\s)|,?\s*\b(?:and|or|but)(?=[a-z]{1,4}\s))(z?[a-z]|[ivxl]{1,4})\s+(?=\S)/u

  @num "(?:[\\dIVXL]+[A-Z]*|\\([a-zA-Z\\d]+\\))(?:\\s*\\([a-zA-Z\\d]+\\))*"
  @numlist "#{@num}(?:\\s*(?:,|and|or|to|-|–)\\s*(?:#{@num}|\\([a-zA-Z\\d]+\\)))*"
  @kind_re "(sub-?paragraph|subparagraph|subsection|section|regulation|article|rule|paragraph|part|chapter|schedule|annex)(s?)"
  @place "(?:England and Wales|the United Kingdom|Great Britain|Northern Ireland|Scotland|England|Wales|the Isle of Man|the Channel Islands|Gibraltar)"

  @kinds %{
    "section" => "SEC",
    "regulation" => "REG",
    "article" => "ART",
    "rule" => "RULE",
    "paragraph" => "PARA",
    "sub-paragraph" => "SUBPARA",
    "subparagraph" => "SUBPARA",
    "subsection" => "SUBSEC",
    "part" => "PART",
    "chapter" => "CHAPTER",
    "schedule" => "SCH",
    "annex" => "ANNEX",
    "title" => "TITLE"
  }

  @keep MapSet.new(
          ~w(of and or to in other than except excluding including so far as
    insofar relating relates relate extend extends apply applies only not
    amendments amendment repeals repeal revocations made by same extent
    those that with together but it they relation the following provisions
    provision paragraphs paragraph sections section does do also save apart from subject has have effect this any)
        )

  @token ~r/^(?:[A-Z_]{2,}S?|GAP|N|\(DESC\)|PLACES?)$/u
  @list_words ~r/\b(?:extends?|appl(?:y|ies)|same extent|so far as|in so far|insofar|other than|except|excluding|including)\b/u
  @kinds_order ~w(sentence lead item other_item)

  @typedoc "A mined item: its sentence row, kind, letter, text, fine and coarse shapes."
  @type item :: %{
          row: map(),
          kind: String.t(),
          letter: String.t(),
          text: String.t(),
          fine: String.t(),
          shape: String.t()
        }

  @doc "`sentences.tsv` (law, ref, class, sentence) → `%{items:, shapes:, stats:}` as iodata."
  @spec run(String.t()) :: %{items: iodata(), shapes: iodata(), stats: iodata()}
  def run(sentences_tsv) do
    rows = PyCompat.dict_rows(sentences_tsv)
    items = Enum.flat_map(rows, &items/1)
    shapes = shapes(items)

    %{
      items: [
        "law\tref\tclass\tkind\tletter\tshape\tfine\ttext\n"
        | Enum.map(items, &item_line/1)
      ],
      shapes: shapes_tsv(shapes),
      stats: [PyCompat.json(stats(shapes, rows), 2)]
    }
  end

  @doc "A sentence's lead and its lettered items, in order (`[]` when not lettered)."
  @spec split(String.t()) :: {String.t(), [{String.t(), String.t()}]}
  def split(sentence) do
    case Regex.scan(@mark, sentence, return: :index) do
      [] ->
        {sentence, []}

      [[{first, _} | _] | _] = marks ->
        # each item runs from its mark's end to the next mark's start, the last to the end
        nexts = Enum.map(tl(marks), fn [{s, _} | _] -> s end) ++ [byte_size(sentence)]

        items =
          Enum.zip_with(marks, nexts, fn [{s, l}, {gs, gl}], next ->
            {binary_part(sentence, gs, gl), binary_part(sentence, s + l, next - s - l)}
          end)

        {binary_part(sentence, 0, first), items}
    end
  end

  @doc "A text with its references, places, laws and descriptions masked (the fine shape)."
  @spec mask(String.t()) :: String.t()
  def mask(text) do
    text
    |> substitute()
    |> then(&Regex.replace(~r/\((?:[^()]|\([^()]*\))*\)/u, &1, fn m -> description(m) end))
    |> then(&Regex.replace(~r/\s+/u, &1, " "))
    |> PyCompat.strip()
    |> PyCompat.rstrip(" .;,")
  end

  # a bracket left with only words is a description
  defp description(m) do
    if Regex.match?(~r/\b[A-Z_]{2,}\b/u, m) and
         Regex.match?(~r/\b(?:other than|except|so far|and|with|including|but)\b/u, m),
       do: m,
       else: " (DESC) "
  end

  defp substitute(t) do
    t
    |> rep(~r/\.\s\.\s\.(?:\s\.)*|…/u, " GAP ")
    |> rep(
      ~r/\bthe\s+(?:[A-Z][\w'’,()-]*\s+(?:of\s+|and\s+|for\s+|the\s+|to\s+|in\s+)*)+(?:Act|Order|Regulations|Rules|Measure)(?:\s+\(Northern Ireland\))?\s+\d{4}(?:\s*\(c\.\s*\d+\)|\s*\(S\.I\.\s*[\d\/]+\))?/u,
      " OTHER_LAW "
    )
    |> rep(~r/\bthe\s+\d{4}\s+(?:Act|Order|Regulations)\b/u, " OTHER_LAW ")
    |> rep(~r/\bthis\s+(?:Act|Order|Regulations|Rules|Measure)\b/u, " THIS_LAW ")
    |> rep(~r/\bthese\s+(?:Regulations|Rules)\b/u, " THIS_LAW ")
    |> rep(
      ~r/\b(this|that)\s+(Part|Chapter|section|Schedule|regulation|article|paragraph|subsection|sub-paragraph|rule)\b/iu,
      fn _, this, kind ->
        " #{String.upcase(this)}_#{Map.get(@kinds, String.downcase(kind), String.upcase(kind))} "
      end
    )
    |> rep(Regex.compile!("\\b#{@kind_re}\\s+(#{@numlist})", "iu"), &reference/4)
    |> rep(~r/\bthe\s+Schedule\b/u, " THE_SCH ")
    |> rep(Regex.compile!(@place, "u"), " PLACE ")
    |> rep(~r/\bPLACE(?:\s*(?:,|and|or)\s*PLACE)+/u, " PLACES ")
    |> rep(~r/\d+/u, " N ")
  end

  defp rep(t, rx, replacement) when is_binary(replacement),
    do: Regex.replace(rx, t, fn _ -> replacement end)

  defp rep(t, rx, fun), do: Regex.replace(rx, t, fun)

  # a reference, singular or a list
  defp reference(_, kind, plural, nums) do
    many = plural != "" or Regex.match?(~r/,|\band\b|\bor\b|\bto\b/u, nums)
    " " <> Map.fetch!(@kinds, String.downcase(kind)) <> if(many, do: "S", else: "") <> " "
  end

  @doc "The coarse shape: tokens and kept words, every other run of words one WORDS."
  @spec coarse(String.t()) :: String.t()
  def coarse(fine) do
    ~r/\(DESC\)|[A-Z_]{2,}S?\b|\w+|[,;()“”"]/u
    |> Regex.scan(fine)
    |> Enum.map(&hd/1)
    |> Enum.reduce([], &coarse_word/2)
    |> Enum.reverse()
    |> Enum.join(" ")
    |> then(&Regex.replace(~r/\s+([,;)])/u, &1, "\\1"))
    |> String.replace("( ", "(")
  end

  defp coarse_word(w, out) do
    token? = Regex.match?(@token, w)

    cond do
      token? ->
        [w | out]

      MapSet.member?(@keep, String.downcase(w)) or w in [",", ";", "(", ")"] ->
        [String.downcase(w) | out]

      out != [] and hd(out) == "WORDS" ->
        out

      true ->
        ["WORDS" | out]
    end
  end

  @doc "An item that names provisions or says where they extend or apply."
  @spec listish?(String.t()) :: boolean()
  def listish?(fine) do
    Regex.match?(~r/^(?:in\s+)?(?:THIS_|THAT_|THE_SCH|GAP|[A-Z]{2,}S?\b)/u, fine) or
      Regex.match?(@list_words, fine)
  end

  defp items(row) do
    {lead, its} = split(row["sentence"])
    kind = if its == [], do: "sentence", else: "lead"

    [
      item(row, kind, "", lead)
      | Enum.map(its, fn {letter, it} -> item(row, "item", letter, it) end)
    ]
  end

  defp item(row, kind, letter, text) do
    fine = mask(text)
    kind = if kind == "item" and not listish?(fine), do: "other_item", else: kind
    %{row: row, kind: kind, letter: letter, text: text, fine: fine, shape: coarse(fine)}
  end

  defp item_line(i) do
    r = i.row

    Enum.join(
      [r["law"], r["ref"], r["class"], i.kind, i.letter, i.shape, i.fine, PyCompat.strip(i.text)],
      "\t"
    ) <> "\n"
  end

  # each shape: count, laws, classes in first-seen order, up to 3 examples from distinct laws
  defp shapes(items) do
    Enum.reduce(items, %{}, fn i, acc ->
      Map.update(acc, {i.kind, i.shape}, add(new_shape(), i), &add(&1, i))
    end)
  end

  defp new_shape, do: %{n: 0, laws: %{}, classes: [], ex: []}

  defp add(e, i) do
    law = i.row["law"]

    ex =
      if length(e.ex) < 3 and law not in Enum.map(e.ex, &elem(&1, 0)),
        do: e.ex ++ [{law, i.row["ref"], i.text |> PyCompat.strip() |> PyCompat.slice(300)}],
        else: e.ex

    %{
      e
      | n: e.n + 1,
        laws: Map.put(e.laws, law, true),
        classes: PyCompat.count(e.classes, i.row["class"]),
        ex: ex
    }
  end

  defp shapes_tsv(shapes) do
    ranked = Enum.sort_by(shapes, fn {key, e} -> {-e.n, key} end)

    [
      "rank\tkind\tcount\tlaws\tclasses\tshape\texamples\n"
      | ranked
        |> Enum.with_index(1)
        |> Enum.map(fn {{{kind, s}, e}, i} ->
          classes =
            Enum.map_join(PyCompat.most_common(e.classes), "; ", fn {c, n} -> "#{c}×#{n}" end)

          ex = Enum.map_join(e.ex, " || ", fn {l, r, t} -> "#{l} #{r}: #{t}" end)
          "#{i}\t#{kind}\t#{e.n}\t#{map_size(e.laws)}\t#{classes}\t#{s}\t#{ex}\n"
        end)
    ]
  end

  defp stats(shapes, rows) do
    [{"scope", "occurrences whose sentence class is not 'none'"}] ++
      Enum.map(@kinds_order, &{&1, kind_stats(shapes, &1)}) ++
      [
        {"sentences", length(rows)},
        {"laws", rows |> Enum.map(& &1["law"]) |> Enum.uniq() |> length()}
      ]
  end

  defp kind_stats(shapes, kind) do
    counts =
      for {{k, _}, e} <- shapes,
          k == kind,
          c = e.n - PyCompat.get(e.classes, "none"),
          c > 0,
          do: c

    {n, s} = {Enum.sum(counts), length(counts)}
    f1 = Enum.count(counts, &(&1 == 1))
    f2 = Enum.count(counts, &(&1 == 2))
    chao1 = if f2 > 0, do: s + f1 * f1 / (2 * f2), else: s + f1 * (f1 - 1) / 2

    [
      {"occurrences", n},
      {"shapes", s},
      {"singletons", f1},
      {"doubletons", f2},
      {"chao1_estimated_shapes", PyCompat.round(chao1)},
      {"good_turing_unseen_mass", if(n > 0, do: PyCompat.round(f1 / n, 3))},
      {"top10_share",
       if(n > 0, do: PyCompat.round(Enum.sum(Enum.take(Enum.sort(counts, :desc), 10)) / n, 3))}
    ]
  end
end
