# usage (from backend/): mix run DIR/verdicts.exs DIR/items.tsv DIR/verdicts.tsv
# CV-S05c step 2: for each list item mine.py split, whether the reader holds
# what it names. The item's kind and place are its own statement's, else its
# sentence's; its provisions are `Credit.own_refs/3`'s (the reader's own
# subject parse); held = the reader's lists of that kind and place.
#   read      every provision it names is held
#   partial   some are held
#   missing   none held, though a list of that kind and place exists
#   unread    no list of that kind and place
#   unparsed  it names a provision the reader parses as none
#   no_refs   it names no provision the reader parses
#   no_list_statement   neither it nor its sentence is a list statement
#   withheld  not held, but every provision it names is in an unread list (deliberate)
#   other_law  it names another law's provisions ("Schedule 2 to the Pensions Act 1995")
# (run-01 step 2b: an item with its own "extend to" is read as its own named
# statement; what it excludes, "(excluding section 53)", is not counted as named)
[src, out] = System.argv()

alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent, RefList}
alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Credit, Forms, Named, Places, ReadCache}
alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

rows =
  src
  |> File.stream!()
  |> Stream.drop(1)
  |> Stream.with_index(2)
  |> Enum.map(fn {line, i} ->
    [law, ref, class, kind, _letter, _shape, _fine, text] =
      line |> String.trim_trailing("\n") |> String.split("\t")

    %{line: i, law: law, ref: ref, class: class, kind: kind, text: text}
  end)

# each item with its sentence (the lead row before it, and the items after)
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
  |> Enum.filter(fn [h | _] -> h.kind == "lead" end)

by_law = Enum.group_by(sentences, fn [h | _] -> h.law end)

other_law = ~r/\b(?:of|to|in)\s*,?\s+(?:the\s+[A-Z][^;]*?\b(?:Act|Order|Regulations|Rules|Measure)\b|that\s+Act)/u
excluded_at = ~r/\b(?:excluding|other\s+than|except)\b/iu

verdict = fn item, sentence, ref, doc, e ->
  st =
    cond do
      Regex.match?(other_law, item) ->
        :other_law

      m = Regex.named_captures(Forms.named(), item) ->
        {:list, Named.named_kind(m), Places.places(m["places"])}

      true ->
        case Extent.statement(item, doc.type) do
          {:list, _, _} = s -> s
          _ -> Extent.statement(sentence, doc.type)
        end
    end

  excluded =
    case Regex.split(excluded_at, item, parts: 2) do
      [_, tail] -> RefList.parse(tail, ref)
      _ -> []
    end

  case st do
    {:list, kind, place} ->
      held = for {^kind, ^place, refs} <- e.lists, r <- refs, do: r

      case Credit.own_refs(item, ref, doc) do
        :unparsed -> {"unparsed", [], held}
        [] -> {"no_refs", [], held}
        own when held == [] ->
          withheld = for {:unread, _, refs} <- e.lists, r <- refs, do: r

          if own != [] and Enum.all?(own, fn r -> "*" in withheld or Enum.any?(withheld, &(&1 == r or RefList.covers?(&1, r))) end),
            do: {"withheld", own, held},
            else: {"unread", own, held}
        own ->
          own = Enum.reject(own, fn r -> Enum.any?(excluded, &(&1 == r or RefList.covers?(&1, r))) end)

          hit = Enum.filter(own, fn r -> "*" in held or Enum.any?(held, &(&1 == r or RefList.covers?(&1, r))) end)

          withheld = for {:unread, _, refs} <- e.lists, r <- refs, do: r
          covered? = fn r -> "*" in withheld or Enum.any?(withheld, &(&1 == r or RefList.covers?(&1, r))) end

          cond do
            length(hit) == length(own) -> {"read", own, held}
            Enum.all?(own -- hit, covered?) -> {"withheld", own, held}
            hit != [] -> {"partial", own, held}
            true -> {"missing", own, held}
          end
      end

    :other_law ->
      {"other_law", [], []}

    _ ->
      {"no_list_statement", [], []}
  end
end

lines =
  by_law
  |> Task.async_stream(
    fn {law, sents} ->
      files = ClmlStore.law_files(law)
      doc = Doc.new(law, Enum.map(files, &(&1 |> File.read!() |> :zlib.gunzip())))
      e = ReadCache.law(law, doc: doc).read

      for [lead | items] <- sents, it <- items do
        whole = lead.text <> "—" <> Enum.map_join(items, "; ", & &1.text)
        {v, own, _held} = verdict.(it.text, whole, it.ref, doc, e)
        Enum.join([it.line, law, it.ref, it.kind, v, Enum.join(own, " ")], "\t")
      end
    end,
    max_concurrency: 2,
    timeout: :infinity
  )
  |> Enum.flat_map(fn {:ok, l} -> l end)

File.write!(out, "items_line\tlaw\tref\tkind\tverdict\town_refs\n" <> Enum.join(Enum.sort(lines), "\n") <> "\n")
IO.puts("#{map_size(by_law)} laws, #{length(lines)} items")
