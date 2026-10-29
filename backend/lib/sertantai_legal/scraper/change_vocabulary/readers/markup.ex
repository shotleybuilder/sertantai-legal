defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup do
  @moduledoc """
  The CLML change markup as claims (change vocabulary, CV-02 slice): each
  change id (an `Addition`, `Substitution` or `Repeal` element, however many
  times it occurs) is one change, on the lowest provision holding all its
  occurrences whose own number, heading or text it touches — else on each
  provision (or group's row) under it where it sits — keyed by the effect id its ChangeId carries
  (`EffectIndex.effect_id/1`), else the ChangeId itself.

  Claims (source `:markup`): `operation` (Repeal → repealed, a Repeal paired
  with a substitution → substituted, Substitution → substituted, Addition →
  inserted), `level` (`:provision` when the change wraps the provision's
  number, else `:words`), `retained` (RetainText), `territory` (the Extent
  attribute), `cited` — the law the change's note cites — and `affecting`
  — the amending provisions the note names after it. Both are pointers for
  identity only (`ChangeVocabulary.Merge`; Jason 2026-10-22), never facts.

  A heading's change (`P1group/Title`) is on the provision the group holds.
  Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Pointer}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Ref}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.ListItems
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.NoteLaw
  alias SertantaiLegal.Scraper.EffectIndex
  alias SertantaiLegal.Scraper.Commencement.Order

  @changes ~w(Addition Substitution Repeal)a

  @doc """
  Provision facts the markup states (CV-03), by ref:
  - `prospective` — the provision is within an element marked
    `Status="Prospective"` (not yet in force in the revised text);
  - `shows_text` — the provision still shows words (a removal there with no
    Repeal markup is retained elsewhere: V1-04);
  - `versions` — the territories of its territorial versions (one element
    per territory sharing the provision's id, told apart by their
    DocumentURI: `…/regulation/36/england`, `…/wales`; C3).
  """
  @spec provisions(String.t(), String.t() | nil) :: %{String.t() => map()}
  def provisions(xml, law_name \\ nil) do
    doc = SweetXml.parse(xml, quiet: true, namespace_conformant: false)

    # the status sits on the provision or an element around it (a P1group
    # has no id: Building Safety Act 2022 s.138)
    prospective =
      for el <- xpath(doc, ~x"//*[@Status='Prospective']/descendant-or-self::*[@id]"l),
          ref = el |> xpath(~x"./@id"s) |> Ref.from_clml(law_name),
          ref != nil,
          into: %{},
          do: {ref, %{prospective: true}}

    versions =
      for el <- xpath(doc, ~x"//*[@id][@DocumentURI]"l),
          territory = el |> xpath(~x"./@DocumentURI"s) |> version_territory(),
          territory != nil,
          ref = el |> xpath(~x"./@id"s) |> Ref.from_clml(law_name),
          ref != nil do
        {ref, territory}
      end
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {ref, ts} -> {ref, %{versions: Enum.uniq(ts)}} end)

    # a provision still showing words (letters or numbers, not only "…"):
    # a removal there is retained elsewhere (V1-04)
    text =
      for el <- xpath(doc, ~x"//*[@id]"l),
          ref = el |> xpath(~x"./@id"s) |> Ref.from_clml(law_name),
          ref != nil,
          # its own words: not its number, title or sub-provisions
          String.length(el |> own() |> letters()) >= 2,
          into: %{},
          do: {ref, %{shows_text: true}}

    [prospective, versions, text]
    |> Enum.reduce(&Map.merge(&2, &1, fn _ref, a, b -> Map.merge(a, b) end))
  end

  @places %{
    "england" => "E",
    "wales" => "W",
    "scotland" => "S",
    "ni" => "NI",
    "northern-ireland" => "NI"
  }

  # ".../regulation/14/1/england+wales+scotland" → "E+W+S"; nil for an
  # unversioned URI
  defp version_territory(uri) do
    last = uri |> String.split("/") |> List.last() |> to_string()
    parts = String.split(last, "+")

    if parts != [] and Enum.all?(parts, &Map.has_key?(@places, &1)),
      do: parts |> Enum.map(&@places[&1]) |> SertantaiLegal.Scraper.Territory.union()
  end

  @doc "The document's provision ids (CLML) in document order, for ranges."
  @spec order(String.t()) :: [String.t()]
  def order(xml) do
    xml
    |> SweetXml.parse(quiet: true, namespace_conformant: false)
    |> xpath(~x"//*[@id]/@id"sl)
  end

  @doc """
  Claim sets `{key, target, claims}`, one per change id and provision; from
  the XML or its parsed document. `xml_ids` (`Ref.xml_ids/2`) names a row
  by its CLML id as the parse does — a Part, Chapter or cross-heading has
  no other name (`pt.1`, `h.3`).
  """
  @spec read(String.t() | tuple(), String.t() | nil, %{String.t() => String.t()}) ::
          [{String.t(), String.t(), [Claim.t()]}]
  def read(xml, law_name \\ nil, xml_ids \\ %{})

  def read(xml, law_name, xml_ids) when is_binary(xml),
    do: xml |> SweetXml.parse(quiet: true, namespace_conformant: false) |> read(law_name, xml_ids)

  def read(doc, law_name, xml_ids) do
    # ids legislation.gov.uk gives several elements (K3: three P2s
    # `article-38-1`, numbered A1, 1 and 3): each is told apart by its number
    repeated =
      doc
      |> xpath(~x"//*[@id]/@id"sl)
      |> Enum.frequencies()
      |> Enum.flat_map(fn {id, n} -> if n > 1, do: [id], else: [] end)
      |> MapSet.new()

    items = ListItems.own_texts(doc, law_name)
    own = Map.merge(own_texts(doc), items)

    ctx = %{
      law: law_name,
      xml_ids: xml_ids,
      repeated: repeated,
      own: own,
      items: MapSet.new(Map.keys(items))
    }

    cited = cited(doc)

    {placed, occurrences} =
      doc |> occurrences([], [], ctx) |> Enum.split_with(&Map.has_key?(&1, :placement))

    {footnote_refs, occurrences} = Enum.split_with(occurrences, &Map.has_key?(&1, :footnote_ref))
    occurrences = in_footnotes(occurrences, footnote_refs)

    changes =
      occurrences
      |> group_changes(cited, ctx)

    # an effect placed by its note ref on a provision where no change
    # element of it sits
    marked = MapSet.new(changes, fn {key, ref, _} -> {key, ref} end)

    placements =
      for %{placement: key, path: [_ | _] = path} <- placed,
          ref = name(List.last(path), ctx),
          ref != nil,
          not MapSet.member?(marked, {key, ref}),
          uniq: true,
          do:
            {key, ref,
             Claim.new(:markup, :placed, true, key) ++
               Claim.new(:markup, :omitted, omitted(List.last(path), ctx), key)}

    changes ++ placements
  end

  # a provision whose text is gone (the omission dots): a whole removal the
  # note marks, never its words (REACH Art 77(2)(b), CV-S08 round 2)
  defp omitted(id, ctx), do: if(Map.get(ctx.own, id) == "", do: true)

  # a change inside a footnote sits where the footnote is referenced, and an
  # EU footnote's change ("O003001M002-f00006") is part of its own
  # ("O003001M002"): the footnote holds a citation the change inserted
  # (Directive 92/85 Art 13a(4); CV-S07 round 5 — it was a change to the
  # whole law, "*"). A footnote no provision references places nothing.
  defp in_footnotes(occurrences, refs) do
    at = Map.new(refs, &{&1.footnote_ref, &1.path})

    Enum.flat_map(occurrences, fn
      %{footnote: nil} = o ->
        [o]

      %{footnote: f} = o ->
        case Map.get(at, f) do
          nil ->
            []

          path ->
            [
              %{
                o
                | path: path,
                  change_id: String.replace(o.change_id, ~r/^(O\d+M\d+)-f\d+$/, "\\1")
              }
            ]
        end
    end)
  end

  @doc """
  A change's key: the effect id its ChangeId carries (`key-<hex>`, whatever
  follows it: `-1473449269178`, `-1790691857434/2`), else the ChangeId
  (a legacy id: `d29p1234`, `M_F_…`).
  """
  @spec key(String.t()) :: String.t()
  def key(change_id) do
    case Regex.run(~r/^key-[0-9a-f]{32}/, change_id) do
      [effect] -> effect
      nil -> EffectIndex.effect_id(change_id) || change_id
    end
  end

  # a retained substitution's new words (an Addition the Repeal's
  # SubstitutionRef names) are the same change as the old words: one
  # substitution (catalogue finding D)
  defp group_changes(occurrences, cited, ctx) do
    substituted =
      for %{substitution_ref: ref, change_id: id} <- occurrences,
          ref != nil,
          into: %{},
          do: {ref, id}

    occurrences
    |> Enum.group_by(&Map.get(substituted, &1.change_id, &1.change_id))
    |> Enum.flat_map(fn {change_id, occ} ->
      key = key(change_id)

      for {ref, xml_id, group} <- placements(change_id, occ, ctx),
          do: {key, ref, claims(change_id, group, xml_id, cited, ctx)}
    end)
  end

  # where a change id's occurrences land: the lowest provision holding them
  # all. Where that is a group (a Part, Chapter or cross-heading), each
  # provision under it is placed apart, and the group's own heading or text
  # is a change to the group's row (catalogue finding A). With none (they
  # span the law) — a legacy id is a change to the whole law ("*", a
  # whole-Act repeal for a territory: Forestry Act 1967), an effect id is a
  # change to each top provision it touches; outside any provision (an
  # empty path) it lands nowhere
  defp placements(change_id, occ, ctx) do
    case occ |> Enum.map(& &1.path) |> common() do
      [] ->
        if EffectIndex.effect_id(key(change_id)) do
          occ
          |> Enum.reject(&(&1.path == []))
          |> Enum.group_by(&List.first(&1.path))
          |> Enum.flat_map(fn {_top, group} -> placements(change_id, group, ctx) end)
        else
          [{"*", "*", occ}]
        end

      common ->
        id = List.last(common)

        depth = length(common)

        # a provision placed whole when the change touches its own number,
        # heading or text, or covers all the text under it (a repeal round
        # every sub-provision: Coronavirus Act 2020 s.78); a change only in
        # some provisions under it (two subsections inserted) is placed on
        # each of them (finding H), as under a group
        if provision?(id, ctx) and
             (Enum.any?(occ, &(length(&1.path) == depth)) or
                covers_own_text?(occ, Map.get(ctx.own, id))) do
          [{name(id, ctx), id, occ}]
        else
          occ
          |> Enum.group_by(&Enum.at(&1.path, depth))
          |> Enum.flat_map(fn
            {nil, group} ->
              case name(id, ctx) do
                nil -> []
                ref -> [{ref, id, group}]
              end

            {_child, group} ->
              placements(change_id, group, ctx)
          end)
        end
    end
  end

  # the ids every path shares, outermost first
  defp common(paths) do
    Enum.reduce(paths, fn p, acc ->
      acc |> Enum.zip(p) |> Enum.take_while(fn {a, b} -> a == b end) |> Enum.map(&elem(&1, 0))
    end)
  end

  # a row's ref: as the parse names it, else from its CLML id
  defp name(id, ctx), do: Map.get(ctx.xml_ids, id) || Ref.from_clml(id, ctx.law)

  defp provision?(id, ctx), do: Ref.from_clml(id, ctx.law) != nil

  # the ids that name rows: provisions, and the groups that hold them
  # (Parts, Chapters, cross-headings, EU Sections) — not a defined term's
  # or a citation's id inside a provision (catalogue finding B)
  defp row_id?(id, ctx),
    do: provision?(id, ctx) or Map.has_key?(ctx.xml_ids, id) or Ref.group?(id, ctx.law)

  # every change element with the path of row ids above it, and whether it
  # sits in the provision's number; a group's title belongs to the
  # provision the group holds
  defp occurrences(
         {:xmlElement, name, _, _, _, _, _, attrs, children, _, _, _} = el,
         path,
         flags,
         ctx
       ) do
    id = attr(attrs, :id) |> renumbered(el, ctx) || ListItems.id(name, attrs, path, ctx.law)
    path = if id && row_id?(id, ctx), do: path ++ [id], else: path
    # a provision's number, or a group's (a Part, Chapter or EU Title:
    # SI 2009/1348 Pt.4A inserted whole, CV-S08 round 1)
    flags = if name in [:Pnumber, :Number], do: [:number | flags], else: flags

    flags =
      if name == :Footnote and attr(attrs, :id),
        do: [{:footnote, attr(attrs, :id)} | flags],
        else: flags

    title_path = if name == :P1group, do: path ++ List.wrap(group_provision(el)), else: path

    own =
      cond do
        # a note ref carrying an effect id: where that event sits in the
        # text (its id, not its note's words)
        name == :CommentaryRef and String.starts_with?(attr(attrs, :Ref) || "", "key-") ->
          [%{placement: attr(attrs, :Ref), path: path}]

        # where a footnote is referenced (its changes are placed there)
        name == :FootnoteRef and attr(attrs, :Ref) != nil ->
          [%{footnote_ref: attr(attrs, :Ref), path: path}]

        true ->
          []
      end ++
        if name in @changes and attr(attrs, :ChangeId) do
          [
            %{
              change_id: attr(attrs, :ChangeId),
              kind: name,
              path: path,
              number?: :number in flags,
              retain: attr(attrs, :RetainText) == "true",
              paired: attr(attrs, :SubstitutionRef) != nil,
              substitution_ref: attr(attrs, :SubstitutionRef),
              extent: attr(attrs, :Extent),
              note: attr(attrs, :CommentaryRef),
              heading?: :heading in flags,
              footnote:
                Enum.find_value(flags, fn f ->
                  with {:footnote, id} <- f, do: id, else: (_ -> nil)
                end),
              text: letters(el)
            }
          ]
        else
          []
        end

    own ++
      Enum.flat_map(children, fn
        {:xmlElement, :Title, _, _, _, _, _, _, _, _, _, _} = title ->
          occurrences(title, title_path, [:heading | flags], ctx)

        child ->
          occurrences(child, path, flags, ctx)
      end)
  end

  defp occurrences(_other, _path, _flags, _ctx), do: []

  defp group_provision(group) do
    case xpath(group, ~x"./*[@id][1]/@id"s) do
      "" -> nil
      id -> id
    end
  end

  defp claims(change_id, occ, target, cited, ctx) do
    first = hd(occ)
    repeal = Enum.find(occ, &(&1.kind == :Repeal))

    whole? = whole?(change_id, occ, target, ctx)

    operation =
      cond do
        repeal && repeal.paired -> :substituted
        first.kind == :Repeal -> :repealed
        first.kind == :Substitution -> :substituted
        true -> :inserted
      end

    Enum.concat([
      Claim.new(:markup, :operation, operation, change_id),
      Claim.new(:markup, :level, if(whole?, do: :provision, else: :words), change_id),
      Claim.new(
        :markup,
        :retained,
        if(first.kind == :Repeal or (repeal && repeal.paired), do: repeal.retain),
        change_id
      ),
      Claim.new(:markup, :territory, Enum.find_value(occ, & &1.extent) |> code(), change_id),
      Claim.new(:markup, :cited, get_in(cited, [first.note, :law]), change_id),
      Claim.new(:markup, :cited_text, get_in(cited, [first.note, :text_law]), change_id),
      Claim.new(:markup, :affecting, get_in(cited, [first.note, :refs]), change_id),
      # pointers for identity (CV-S07 round 2): the note the change hangs on
      # (its copies in each version share it), and a change wholly in a
      # heading
      Claim.new(:markup, :note, first.note, change_id),
      Claim.new(:markup, :note_digest, get_in(cited, [first.note, :digest]), change_id),
      Claim.new(:markup, :heading, if(Enum.all?(occ, & &1.heading?), do: true), change_id)
    ])
  end

  # Whole provision: the change wraps its number; or it removes all the
  # text under it (1988/52 s.4(6): a RetainText Repeal round the text, not
  # the number; Coronavirus Act 2020 s.78: round every sub-provision), or
  # its words are gone and the repeal sits on its heading (an EU Article
  # repealed, its text dots: Directive 2002/44 Art 12, CV-S08 round 2); or
  # new text covers all of it (s.1(2A) inserted, its number outside) —
  # except a Substitution with the number outside, which replaces the words
  # ("for 'the … Regulations 2006' substitute '… 2012'" in reg.12(5)(b),
  # whose text is that title: CV-S08 round 1), unless it is a retained
  # substitution's new version or an EU list item, whose number no change
  # can wrap
  defp whole?(change_id, occ, target, ctx) do
    first = hd(occ)
    own = Map.get(ctx.own, target)

    Enum.any?(occ, &(&1.number? and (target == "*" or List.last(&1.path) == target))) or
      (first.kind == :Repeal and own == "") or
      ((first.kind != :Substitution or Enum.any?(occ, &(&1.change_id != change_id)) or
          MapSet.member?(ctx.items, target)) and covers_own_text?(occ, own))
  end

  defp covers_own_text?(_occ, nil), do: false
  defp covers_own_text?(_occ, ""), do: false

  defp covers_own_text?(occ, own_text),
    do: String.contains?(occ |> Enum.map(& &1.text) |> Enum.join(), own_text)

  # the text under each provision (not its own number or title), letters
  # and digits only — to tell a change round all of it
  defp own_texts(doc) do
    for el <- xpath(doc, ~x"//*[@id]"l),
        id = xpath(el, ~x"./@id"s),
        into: %{},
        do: {id, el |> body() |> letters()}
  end

  defp body({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el) do
    put_elem(
      el,
      8,
      Enum.reject(
        children,
        &match?({:xmlElement, n, _, _, _, _, _, _, _, _, _, _} when n in [:Pnumber, :Title], &1)
      )
    )
  end

  defp own({:xmlElement, _, _, _, _, _, _, _, children, _, _, _} = el) do
    kept =
      Enum.flat_map(children, fn
        {:xmlElement, name, _, _, _, _, _, attrs, _, _, _, _} = c ->
          if name in [:Pnumber, :Title] or attr(attrs, :id), do: [], else: [own(c)]

        other ->
          [other]
      end)

    put_elem(el, 8, kept)
  end

  defp letters(el), do: el |> Doc.text() |> String.replace(~r/[^\p{L}\p{N}]/u, "")

  # each commentary's first cited law, as a law name ("UK_uksi_2023_911"),
  # and the amending provisions it names — pointers for identity only (Jason
  # 2026-10-22: the merge may use them to tell same-day events by one law
  # apart; never stored as facts or labelled). The provisions are the note's
  # own structured pointers (finding G): its `CitationSubRef`s of that
  # Citation, the operative ones where it marks them ("(with reg. 3)" and
  # another law's "(as amended by …)" are not), each `SectionRef` a ref
  # ("schedule-2-paragraph-15-a-i-aa" → "sch.2.para.15(a)(i)(aa)"); a note
  # with none falls back to its words (`AmendingLaw.Pointer`)
  defp cited(doc) do
    for c <- xpath(doc, ~x"//Commentary"l),
        id = xpath(c, ~x"./@id"s),
        id != "",
        into: %{},
        do: {id, cited_entry(c)}
  end

  # a note with a `Citation` link: its law, and the provisions it names; a
  # note with none: the law its words cite, for identity only (CV-S07 round
  # 2, decision 3: "S.I. 2004/ 1822" — never the change's `by`)
  defp cited_entry(c) do
    citation = xpath(c, ~x"(.//Citation[@URI])[1]"e)
    # the note's words, normalised: copies of one note in each version of a
    # provision carry their own ids but the same words (HSWA s.28: E+W, S,
    # NI; CV-S07 round 3) — a pointer for identity only
    digest = NoteLaw.digest(Doc.text(c))

    case citation && Regex.run(~r"/id/([a-z]+)/(\d{4})/(\d+)", xpath(citation, ~x"./@URI"s)) do
      [_, type, year, num] ->
        law = "UK_#{type}_#{year}_#{num}"
        refs = pointers(c, xpath(citation, ~x"./@id"s), law)
        %{law: law, refs: if(refs != [], do: refs), digest: digest}

      _ ->
        case NoteLaw.law(Doc.text(c)) do
          nil ->
            %{digest: digest}

          law ->
            refs = pointers(c, "", law)
            %{text_law: law, refs: if(refs != [], do: refs), digest: digest}
        end
    end
  end

  defp pointers(commentary, citation_id, law) do
    subrefs =
      for s <- xpath(commentary, ~x".//CitationSubRef"l),
          citation_id != "" and xpath(s, ~x"./@CitationRef"s) == citation_id,
          do: {xpath(s, ~x"./@SectionRef"s), xpath(s, ~x"./@Operative"s) == "true"}

    case subrefs do
      [] ->
        %{text: Doc.text(commentary), citation_law: law}
        |> Pointer.parse()
        |> Map.get(:provisions)
        |> Enum.flat_map(&Pointer.to_refs/1)

      subrefs ->
        operative = for {ref, true} <- subrefs, do: ref

        if(operative != [], do: operative, else: Enum.map(subrefs, &elem(&1, 0)))
        |> Enum.map(&pointer_ref/1)
        |> Enum.reject(&is_nil/1)
        |> Enum.uniq()
    end
  end

  # a pointer's SectionRef as a ref, named as the feed reader names the
  # feed's affecting provisions (a Schedule's paragraph by its Schedule,
  # its Part left out: "schedule-10-part-5-paragraph-9" → "sch.10.para.9");
  # an unnumbered Schedule's "schedule-paragraph-3-3" → "sch.para.3(3)"
  defp pointer_ref(section_ref) do
    case Regex.run(
           ~r/^schedule(?:-([^-]+))?(?:-part-[^-]+)?-paragraph-([^-]+)((?:-[^-]+)*)$/,
           section_ref
         ) do
      [_, sch, para, rest] ->
        subs = rest |> String.split("-", trim: true) |> Enum.map_join(&"(#{&1})")
        if(sch == "", do: "sch.para.", else: "sch.#{sch}.para.") <> para <> subs

      nil ->
        Order.ref(section_ref)
    end
  end

  # a repeated id (K3) named by the element's own number: `article-38-1`
  # numbered 3 → `article-38-3`, as the parse names its row (finding I)
  defp renumbered(nil, _el, _ctx), do: nil

  defp renumbered(id, el, ctx) do
    with true <- MapSet.member?(ctx.repeated, id),
         pnumber when pnumber != nil <- xpath(el, ~x"./Pnumber"e),
         number when number != "" <-
           pnumber |> Doc.text() |> String.replace(~r/[\s()]/u, ""),
         [_, stem, last] <- Regex.run(~r/^(.*-)([^-]+)$/, id),
         true <- last != number do
      stem <> number
    else
      _ -> id
    end
  end

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} -> to_string(value)
      _ -> nil
    end)
  end

  defp code(nil), do: nil
  defp code(value), do: SertantaiLegal.Scraper.Territory.normalize(value)
end
