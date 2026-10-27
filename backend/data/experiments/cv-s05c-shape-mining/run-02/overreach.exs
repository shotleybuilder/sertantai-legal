# usage (from backend/): mix run DIR/overreach.exs DIR/items.tsv DIR/overreach.tsv
# CV-S05c shape review, step 3: over-reach in list items the reader holds.
# For each item of a sentence the reader classes as a list, against the stored
# lists of the item's kind and place (as verdicts.exs):
#   excluded   a provision the item excludes ("other than", "except",
#              "excluding", "apart from", "with the exception of") is held
#   qualified  a provision named only in a qualified chunk ("section 73 so far
#              as relating to those Parts") is held as plain
#   scope      "in Part N, sections …": every section of Part N is held, though
#              the item names only some
[src, out] = System.argv()

alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent, RefList}
alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Forms, Named, Parts, Places}
alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

rows =
  src
  |> File.stream!()
  |> Stream.drop(1)
  |> Stream.with_index(2)
  |> Enum.map(fn {line, i} ->
    [law, ref, class, kind, _letter, shape, _fine, text] =
      line |> String.trim_trailing("\n") |> String.split("\t")

    %{line: i, law: law, ref: ref, class: class, kind: kind, shape: shape, text: text}
  end)

sentences =
  rows
  |> Enum.chunk_while(
    [],
    fn r, acc ->
      if r.kind in ["lead", "sentence"] and acc != [],
        do: {:cont, Enum.reverse(acc), [r]},
        else: {:cont, [r | acc]}
    end,
    fn acc -> {:cont, Enum.reverse(acc), []} end
  )
  |> Enum.filter(fn [h | _] -> h.kind == "lead" and String.starts_with?(h.class, "list") end)

by_law = Enum.group_by(sentences, fn [h | _] -> h.law end)

other_law =
  ~r/\b(?:of|to|in)\s*,?\s+(?:the\s+[A-Z][^;]*?\b(?:Act|Order|Regulations|Rules|Measure)\b|that\s+Act)/u

excl =
  ~r/\b(?:other\s+than|except(?:\s+for)?|excluding|apart\s+from|with\s+the\s+exception\s+of)\s+(?<ex>(?:[^()]|\([^()]*\))*?)(?:\)|$|;|,\s*(?:and|but)\b)/iu

mention =
  ~r/\b(?:this\s+(?:section|article|regulation|rule|Part)\b|(?:sections?|articles?|regulations?|rules?|paragraphs?|Parts?|Chapters?|Schedules?)\s+[\dIVXLC]+[A-Z]*\b)/iu

qual = ~r/\b(?:so\s+far|in\s*so\s*far|insofar|to\s+the\s+extent)\b/iu

in_scope =
  ~r/^\s*in\s+(?<scope>(?:Chapter\s+\S+\s+of\s+)?Part\s+[\dIVXLC]+[A-Z]*)\b[^,]*,\s*(?<rest>sections?\b.*)$/iu

refs = fn text, ref, doc ->
  Enum.uniq(RefList.parse(text, ref) ++ Parts.parts(Parts.qualify_chapters(text), doc, ref))
end

held? = fn held, r -> "*" in held or Enum.any?(held, &(&1 == r or RefList.covers?(&1, r))) end

statement = fn item, sentence, doc ->
  cond do
    Regex.match?(other_law, item) ->
      nil

    m = Regex.named_captures(Forms.named(), item) ->
      {:list, Named.named_kind(m), Places.places(m["places"])}

    true ->
      case Extent.statement(item, doc.type) do
        {:list, _, _} = s -> s
        _ -> Extent.statement(sentence, doc.type)
      end
  end
end

checks = fn item, ref, doc, held ->
  ex =
    for m <- Regex.scan(excl, item, capture: ["ex"]),
        [e] = m,
        r <- refs.(e, ref, doc),
        held?.(held, r),
        uniq: true,
        do: r

  # chunks cut at each provision named; a chunk with a qualifier, and the
  # provisions named only there
  starts = for [{at, _}] <- Regex.scan(mention, item, return: :index), do: at
  ends = Enum.drop(starts, 1) ++ [byte_size(item)]
  chunks = for {a, b} <- Enum.zip(starts, ends), do: binary_part(item, a, b - a)
  {q, plain} = Enum.split_with(chunks, &Regex.match?(qual, &1))
  plain_refs = Enum.flat_map(plain, &refs.(&1, ref, doc))

  q_only =
    for c <- q,
        r <- refs.(c, ref, doc),
        r not in plain_refs,
        held?.(held, r),
        not Enum.any?(plain_refs, &RefList.covers?(&1, r)),
        uniq: true,
        do: r

  scope =
    case Regex.named_captures(in_scope, item) do
      %{"scope" => s, "rest" => rest} ->
        named = refs.(rest, ref, doc)
        all = Parts.parts(Parts.qualify_chapters(s), doc, ref)
        extra = Enum.reject(all, &(&1 in named))
        if extra != [] and Enum.all?(extra, &held?.(held, &1)), do: extra, else: []

      _ ->
        []
    end

  for {rule, rs} <- [excluded: ex, qualified: q_only, scope: scope], rs != [], do: {rule, rs}
end

lines =
  by_law
  |> Task.async_stream(
    fn {law, sents} ->
      files = ClmlStore.law_files(law)
      doc = Doc.new(law, Enum.map(files, &(&1 |> File.read!() |> :zlib.gunzip())))
      e = SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache.law(law, doc: doc).read

      for [lead | items] <- sents, it <- items, it.kind in ["item", "other_item"] do
        whole = lead.text <> "—" <> Enum.map_join(items, "; ", & &1.text)

        case statement.(it.text, whole, doc) do
          {:list, kind, place} ->
            held = for {^kind, ^place, rs} <- e.lists, r <- rs, do: r

            for {rule, rs} <- checks.(it.text, it.ref, doc, held) do
              Enum.join(
                [
                  it.line,
                  law,
                  it.ref,
                  it.class,
                  rule,
                  Enum.join(Enum.take(rs, 12), " "),
                  length(rs),
                  it.shape,
                  String.slice(it.text, 0, 250)
                ],
                "\t"
              )
            end

          _ ->
            []
        end
      end
      |> List.flatten()
    end,
    max_concurrency: 2,
    timeout: :infinity
  )
  |> Enum.flat_map(fn {:ok, l} -> l end)

File.write!(
  out,
  "items_line\tlaw\tref\tclass\trule\theld_refs\tn\tshape\ttext\n" <>
    Enum.join(Enum.sort(lines), "\n") <> "\n"
)

IO.puts("#{map_size(by_law)} laws, #{length(lines)} over-reach findings")
