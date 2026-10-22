defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup do
  @moduledoc """
  The CLML change markup as claims (change vocabulary, CV-02 slice): each
  change id (an `Addition`, `Substitution` or `Repeal` element, however many
  times it occurs) is one change, on the lowest provision holding all its
  occurrences, keyed by the effect id its ChangeId carries
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
  alias SertantaiLegal.Scraper.EffectIndex

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

  @doc "Claim sets `{key, target, claims}`, one per change id."
  @spec read(String.t(), String.t() | nil) :: [{String.t(), String.t(), [Claim.t()]}]
  def read(xml, law_name \\ nil) do
    doc = SweetXml.parse(xml, quiet: true, namespace_conformant: false)
    cited = cited(doc)
    own = own_texts(doc)

    {placed, occurrences} =
      doc |> occurrences([], []) |> Enum.split_with(&Map.has_key?(&1, :placement))

    changes =
      occurrences
      |> group_changes(cited, own, law_name)

    # an effect placed by its note ref on a provision where no change
    # element of it sits
    marked = MapSet.new(changes, fn {key, ref, _} -> {key, ref} end)

    placements =
      for %{placement: key, path: [_ | _] = path} <- placed,
          ref = Ref.from_clml(List.last(path), law_name),
          ref != nil,
          not MapSet.member?(marked, {key, ref}),
          uniq: true,
          do: {key, ref, Claim.new(:markup, :placed, true, key)}

    changes ++ placements
  end

  defp group_changes(occurrences, cited, own, law_name) do
    occurrences
    |> Enum.group_by(& &1.change_id)
    |> Enum.flat_map(fn {change_id, occ} ->
      key = EffectIndex.effect_id(change_id) || change_id

      for {ref, xml_id, group} <- placements(change_id, occ, law_name),
          do: {key, ref, claims(change_id, group, xml_id, cited, own)}
    end)
  end

  # where a change id's occurrences land: the lowest provision holding them
  # all; with none (they span the law) — a legacy id is a change to the
  # whole law ("*", a whole-Act repeal for a territory: Forestry Act 1967),
  # an effect id is a change to each top provision it touches
  defp placements(change_id, occ, law) do
    case occ |> Enum.map(& &1.path) |> lowest() do
      nil ->
        if EffectIndex.effect_id(change_id) do
          # outside any provision (an empty path) it lands nowhere
          occ
          |> Enum.reject(&(&1.path == []))
          |> Enum.group_by(&List.first(&1.path))
          |> Enum.flat_map(fn {_top, group} -> placements(change_id, group, law) end)
        else
          [{"*", "*", occ}]
        end

      id ->
        case Ref.from_clml(id, law) do
          nil -> []
          ref -> [{ref, id, occ}]
        end
    end
  end

  # every change element with the path of provision ids above it, and
  # whether it sits in the provision's number; a group's title belongs to
  # the provision the group holds
  defp occurrences({:xmlElement, name, _, _, _, _, _, attrs, children, _, _, _} = el, path, flags) do
    path = if id = attr(attrs, :id), do: path ++ [id], else: path
    flags = if name == :Pnumber, do: [:number | flags], else: flags
    title_path = if name == :P1group, do: path ++ List.wrap(group_provision(el)), else: path

    own =
      cond do
        # a note ref carrying an effect id: where that event sits in the
        # text (its id, not its note's words)
        name == :CommentaryRef and String.starts_with?(attr(attrs, :Ref) || "", "key-") ->
          [%{placement: attr(attrs, :Ref), path: path}]

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
              extent: attr(attrs, :Extent),
              note: attr(attrs, :CommentaryRef),
              text: letters(el)
            }
          ]
        else
          []
        end

    own ++
      Enum.flat_map(children, fn
        {:xmlElement, :Title, _, _, _, _, _, _, _, _, _, _} = title ->
          occurrences(title, title_path, flags)

        child ->
          occurrences(child, path, flags)
      end)
  end

  defp occurrences(_other, _path, _flags), do: []

  defp group_provision(group) do
    case xpath(group, ~x"./*[@id][1]/@id"s) do
      "" -> nil
      id -> id
    end
  end

  # the deepest id every occurrence's path shares
  defp lowest(paths) do
    paths
    |> Enum.reduce(fn p, acc ->
      acc |> Enum.zip(p) |> Enum.take_while(fn {a, b} -> a == b end) |> Enum.map(&elem(&1, 0))
    end)
    |> List.last()
  end

  defp claims(change_id, occ, target, cited, own) do
    first = hd(occ)

    # whole provision: the change wraps its number, or all the text under it
    # (1988/52 s.4(6): a RetainText Repeal round the text, not the number;
    # Coronavirus Act 2020 s.78: round every sub-provision)
    whole? =
      Enum.any?(occ, &(&1.number? and (target == "*" or List.last(&1.path) == target))) or
        covers_own_text?(occ, Map.get(own, target))

    operation =
      cond do
        first.kind == :Repeal and first.paired -> :substituted
        first.kind == :Repeal -> :repealed
        first.kind == :Substitution -> :substituted
        true -> :inserted
      end

    Enum.concat([
      Claim.new(:markup, :operation, operation, change_id),
      Claim.new(:markup, :level, if(whole?, do: :provision, else: :words), change_id),
      Claim.new(:markup, :retained, if(first.kind == :Repeal, do: first.retain), change_id),
      Claim.new(:markup, :territory, Enum.find_value(occ, & &1.extent) |> code(), change_id),
      Claim.new(:markup, :cited, get_in(cited, [first.note, :law]), change_id),
      Claim.new(:markup, :affecting, get_in(cited, [first.note, :refs]), change_id)
    ])
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
  # and the amending provisions it names after it ("Sch. 2 para. 10(2)(a)"
  # → ["sch.2.para.10(2)(a)"]; `AmendingLaw.Pointer`) — pointers for
  # identity only (Jason 2026-10-22: the merge may use them to tell same-day
  # events by one law apart; never stored as facts or labelled)
  defp cited(doc) do
    for c <- xpath(doc, ~x"//Commentary"l),
        id = xpath(c, ~x"./@id"s),
        uri = xpath(c, ~x"(.//Citation/@URI)[1]"s),
        [_, type, year, num] <- [Regex.run(~r"/id/([a-z]+)/(\d{4})/(\d+)", uri)],
        law = "UK_#{type}_#{year}_#{num}",
        into: %{} do
      refs =
        %{text: Doc.text(c), citation_law: law}
        |> Pointer.parse()
        |> Map.get(:provisions)
        |> Enum.flat_map(&Pointer.to_refs/1)

      {id, %{law: law, refs: if(refs != [], do: refs)}}
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
