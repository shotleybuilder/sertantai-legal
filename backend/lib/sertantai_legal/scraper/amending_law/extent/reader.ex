defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Reader do
  @moduledoc """
  An amending law's extent read from its document (`AmendingLaw.Extent`,
  the struct): `read/1`, its extent and application statements as read;
  `withheld/1`, the same with the bounds its unread statements withhold
  (`Patterns.classes/2`, `Unread.withheld/3`) — what `extent_rules` stores
  before the powers are placed (`Extent.Write`). The document reading's
  stamp is this module's reach (`Extent.ReadVersion.Document`). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Extent, ScheduleRefs}

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{
    AmendedExcepted,
    Amends,
    Application,
    Applies,
    Default,
    Excepted,
    Excepting,
    ExceptionList,
    Forms,
    Lists,
    MakesFollowing,
    Named,
    OwnParagraph,
    Patterns,
    QualifiedItems,
    Same,
    ScheduleRest,
    Targeted,
    Units,
    Unread
  }

  alias SertantaiLegal.Scraper.Commencement.ClmlRef
  alias SertantaiLegal.Scraper.Territory

  @doc """
  The law's extent with the bounds its unread statements withhold, and the
  catalogue's classes of its sentences (`Patterns.classes/2`, read against
  the statements): `{extent, classes}`.
  """
  @spec withheld(Doc.t()) :: {Extent.t(), [{String.t(), String.t(), String.t()}]}
  def withheld(%Doc{} = doc) do
    read = read(doc)
    classes = Patterns.classes(doc, read)
    {Unread.withheld(read, classes, doc), classes}
  end

  @doc "The Act's extent clause read from its document; empty when it has none read."
  @spec read(Doc.t()) :: Extent.t()
  def read(%Doc{} = doc) do
    # lines joined with spaces: a paragraph label never runs into the
    # words before it ("Schedule 10.7 The following …")
    sections =
      for id <- doc.ids,
          ref = ClmlRef.ref(id),
          ref != nil,
          do:
            {ref,
             doc
             |> Doc.element(id)
             |> Units.own_words()
             |> Doc.lines()
             |> Enum.join(" ")
             |> Units.unlettered()
             |> Default.except_first()}

    # built once: the named and same-extent readers both walk them
    unit_sentences = Units.unit_sentences(doc)

    clauses = Enum.filter(sections, fn {ref, text} -> clause?(ref, text) end)

    # the first stating a default, else the first: "31 The following
    # provisions … do not extend to Scotland— …"; "32 It is hereby declared
    # that this Act extends to Northern Ireland" (ukpga 1981/45, CV-S05
    # round 8 NEW-4; s.31's list is read as any other provision's)
    {clause_ref, clause} =
      Enum.find(clauses, List.first(clauses, {nil, ""}), fn {_, text} ->
        Default.default(text) != nil
      end)

    default =
      Default.default(clause)
      |> Default.westminster(clause, doc.type)
      |> Default.narrowed(clauses, clause_ref)

    # a provision's own application, and an "extends and applies" extent
    applies = Applies.applies(doc)

    introduced_by = introductions(doc)

    %Extent{
      default: default,
      lists:
        (Lists.apart(clause, clause_ref, doc) ++
           Lists.only_following(clause, clause_ref, doc) ++
           Lists.extends_except(clause, clause_ref, doc) ++
           Default.exception_lists(clause, clause_ref, doc) ++
           Lists.headed_lists(sections, clause_ref, clause, doc) ++
           Lists.late_lists(sections, doc) ++
           Lists.part_not(sections, doc) ++
           Named.named(unit_sentences, doc) ++
           Excepting.leads(unit_sentences, doc) ++
           MakesFollowing.lists(unit_sentences, doc) ++
           [:same] ++
           Amends.amends(unit_sentences, doc) ++
           Excepted.excepted(unit_sentences, doc) ++
           OwnParagraph.lists(doc) ++
           QualifiedItems.lists(unit_sentences, doc) ++
           extent_entries(applies))
        |> with_same(Same.amendments_same(unit_sentences, doc, default))
        |> Enum.flat_map(&excepted(&1, default))
        |> with_schedule_rest(unit_sentences, default, introduced_by, doc),
      corresponds: Regex.match?(~r/\bcorresponds\s+to\s+the\s+repeal\b/i, clause),
      introduced_by: introduced_by,
      ref: clause_ref,
      text: if(clause != "", do: clause),
      application: Application.application(doc, Default.default(clause)),
      applies: for({k, _, _} = a <- applies, k in [:applies, :applies_not], do: a),
      # the changes' own targets' extent ("The repeal of section 4(8)
      # extends also to Scotland": `Targeted`, CV-S05f)
      # (and of an exception to the same extent naming the provisions
      # amended: `AmendedExcepted`)
      targets: Targeted.lists(doc) ++ AmendedExcepted.targets(unit_sentences, default)
    }
  end

  # a top-level provision whose words state an extent (a clause candidate)
  defp clause?(ref, text), do: not String.contains?(ref, "(") and states_extent?(text)

  defp states_extent?(text) do
    ExceptionList.match?(text) or
      Enum.any?(
        [
          Forms.extends(),
          Forms.extends_and(),
          Forms.not_extends(),
          Forms.heading(),
          Forms.cited_list(),
          Forms.only_following(),
          Forms.extends_except(),
          Forms.extends_exc()
        ],
        &Regex.match?(&1, text)
      )
  end

  # the same-extent lists in their place, less any another reader states
  # too (a lettered exception's own extent: `SameExceptions`)
  defp with_same(lists, same) do
    Enum.flat_map(lists, fn
      :same -> Enum.reject(same, &(&1 in lists))
      list -> [list]
    end)
  end

  # a Schedule's paragraphs no list names, its introducing section withheld
  # only for those the lists do name: the default (`ScheduleRest`)
  defp with_schedule_rest(lists, unit_sentences, default, introduced_by, doc),
    do: lists ++ ScheduleRest.lists(unit_sentences, lists, default, introduced_by, doc)

  defp extent_entries(applies), do: for({k, _, _} = a <- applies, k in [:only, :named], do: a)

  # a list item's own exceptions (`Lists`: "Part 5 …, except— i …") keep
  # the default: what the list adds is taken from them; with no default,
  # unknown (CV-S05 round 6)
  defp excepted({:except, place, refs}, default) when is_binary(default) and is_binary(place) do
    case Territory.subtract(place, default) do
      added when added in [nil, ""] -> []
      added -> [{:not, added, refs}]
    end
  end

  defp excepted({:except, _place, refs}, _default), do: [{:unread, nil, refs}]

  # the excepted subdivisions of a provision a narrowing list reads by its
  # other subdivisions (`Extent.Subdivisions`): the default, stated, so the
  # provision's own withholding doesn't reach them; with no default, unknown
  defp excepted({:kept, nil, refs}, default) when is_binary(default),
    do: [{:named, default, refs}]

  defp excepted({:kept, nil, refs}, _default), do: [{:unread, nil, refs}]
  defp excepted(list, _default), do: [list]

  # each Schedule's introducing section (`ScheduleRefs.references/1`,
  # the one reader of it), as refs: "sch.7" => "s.111"
  defp introductions(doc) do
    for {sch, sec} <- ScheduleRefs.references(doc),
        s = ClmlRef.ref(sch),
        r = ClmlRef.ref(sec),
        s != nil and r != nil,
        into: %{},
        do: {s, r}
  end
end
