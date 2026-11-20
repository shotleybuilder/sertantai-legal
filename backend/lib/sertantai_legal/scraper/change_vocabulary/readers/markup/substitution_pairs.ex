defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.SubstitutionPairs do
  @moduledoc """
  Which new words (an Addition) belong to which retained Repeal: each new
  words' ChangeId → the Repeal's.

  A Repeal's SubstitutionRef names its new words, and the pair stands as
  written. One form is mis-pointed: the SubstitutionRef names an Addition
  under another change's note while an Addition under the Repeal's own note
  is named by no SubstitutionRef. The Repeal's new words are then the ones
  under its own note, and the Addition it names stays the other change's —
  Waste and Emissions Trading Act 2003 s.25(2): the E.W. change's Repeal
  names the Wales change's new words; Limited Partnerships Act 1907
  s.6(3D): a 2023 substitution's Repeal names the 2017 insertion round it.

  Where the Repeal's own note has no unnamed Addition the pair stands,
  whatever the notes (SI 2007/1711 reg.16: one change under two note ids;
  EPA 1990 s.6(6B)). Pure.
  """

  import SweetXml

  @typedoc "A change element: its kind, ChangeId, note and SubstitutionRef."
  @type element :: %{
          kind: atom(),
          id: String.t(),
          note: String.t() | nil,
          ref: String.t() | nil
        }

  @doc "Each new words' ChangeId → its Repeal's, from the parsed document."
  @spec read(tuple()) :: %{String.t() => String.t()}
  def read(doc) do
    doc
    |> xpath(~x"//*[@ChangeId]"l)
    |> Enum.map(&element/1)
    |> pairs()
  end

  @doc "Each new words' ChangeId → its Repeal's, from the change elements in document order."
  @spec pairs([element()]) :: %{String.t() => String.t()}
  def pairs(elements) do
    notes = addition_notes(elements)
    own = unnamed_additions(elements)

    for %{ref: ref} = el when ref != nil <- elements,
        new_words <- new_words(el, notes, own),
        into: %{},
        do: {new_words, el.id}
  end

  # the new words of a change element naming some: its own note's unnamed
  # Additions where it names another note's, else the ones it names
  defp new_words(%{note: note, ref: ref}, notes, own) do
    named = Map.get(notes, ref, [])
    own_words = Map.get(own, note, [])

    if note != nil and named != [] and note not in named and own_words != [],
      do: own_words,
      else: [ref]
  end

  # each Addition's ChangeId → the notes its elements carry
  defp addition_notes(elements) do
    for(%{kind: :Addition, note: note} = el when note != nil <- elements, do: {el.id, note})
    |> Enum.uniq()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  # each note → its Additions' ChangeIds no SubstitutionRef names
  defp unnamed_additions(elements) do
    named = for %{ref: ref} when ref != nil <- elements, into: MapSet.new(), do: ref

    for(
      %{kind: :Addition, note: note} = el when note != nil <- elements,
      not MapSet.member?(named, el.id),
      do: {note, el.id}
    )
    |> Enum.uniq()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  defp element({:xmlElement, kind, _, _, _, _, _, attrs, _, _, _, _} = el) do
    %{
      kind: kind,
      id: attr(attrs, :ChangeId),
      note: attr(attrs, :CommentaryRef) || child_note(el),
      ref: attr(attrs, :SubstitutionRef)
    }
  end

  # a note linked by a child `<CommentaryRef Ref=…/>`, not the attribute
  defp child_note(el) do
    case xpath(el, ~x"./CommentaryRef/@Ref"s) do
      "" -> nil
      ref -> ref
    end
  end

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} -> to_string(value)
      _ -> nil
    end)
  end
end
