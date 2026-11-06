defmodule SertantaiLegal.Scraper.ChangeVocabulary.MergeGateTest do
  @moduledoc """
  The merge's family gate (Maritime Safety: Merge, Decision 1): each joined,
  unjoined and candidate change, each markup-only change and each spread
  key, grouped by a cause from code and amending law, with its reviewed
  status.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence, Merge, MergeGate}

  @by "UK_uksi_2019_696"
  @law "UK_uksi_1998_2241"
  @key "#{@by}:schedule-12-paragraph-21-a"

  defp set(key, target, claims),
    do:
      {key, target,
       for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})}

  defp text(key, target, op, date \\ ~D[2020-12-31]),
    do:
      set(key, target, [
        {:law_text, :operation, op},
        {:law_text, :level, :words},
        {:law_text, :by, @by},
        {:commencement, :date, date}
      ])

  defp feed(key, target, op, affecting),
    do:
      set(key, target, [
        {:feed, :operation, op},
        {:feed, :level, :words},
        {:feed, :by, @by},
        {:feed, :date, ~D[2020-12-31]},
        {:feed, :affecting, affecting}
      ])

  defp markup(key, target, op),
    do: set(key, target, [{:markup, :operation, op}, {:markup, :cited, @by}])

  defp merged(sets), do: sets |> Merge.merge() |> Enum.map(&Evidence.resolve(&1, nil))

  defp causes(sets),
    do: @law |> MergeGate.entries(merged(sets)) |> Enum.map(&{&1.cause, &1.target}) |> Enum.sort()

  describe "joined changes, by how they joined" do
    test "one effect id, feed and markup: by design" do
      assert causes([
               feed("key-a", "reg.21", :substituted, []),
               markup("key-a", "reg.21", :substituted)
             ]) == [{"same effect id", "reg.21"}]
    end

    test "the law's text naming the feed's own amending provision, same operation: by design" do
      assert causes([
               text(@key, "reg.21", :substituted),
               feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"])
             ]) == [{"same amending provision, same operation", "reg.21"}]
    end

    test "the law's text joined where the feed names a provision above it, or none" do
      assert causes([
               text(@key, "reg.21", :substituted),
               feed("key-a", "reg.21", :substituted, ["sch.12.para.21"])
             ]) == [{"related amending provision", "reg.21"}]

      assert causes([
               text(@key, "reg.21", :substituted),
               feed("key-a", "reg.21", :substituted, [])
             ]) == [{"legislation.gov.uk names no amending provision", "reg.21"}]
    end

    test "a legacy markup id joined" do
      assert causes([
               feed("key-a", "reg.21", :substituted, []),
               markup("d29p11431", "reg.21", :substituted)
             ]) == [{"legacy markup id", "reg.21"}]
    end

    test "the law's text naming a legacy note's amending provision, or a legacy note naming the feed's" do
      note = fn id, op ->
        set(id, "reg.21", [
          {:markup, :operation, op},
          {:markup, :cited, @by},
          {:markup, :affecting, ["sch.12.para.21(a)"]}
        ])
      end

      assert causes([text(@key, "reg.21", :inserted), note.("d29p11431", :inserted)]) ==
               [{"same amending provision, same operation", "reg.21"}]

      assert causes([
               feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"]),
               note.("d29p11431", :substituted)
             ]) == [{"legacy note names the feed's amending provision", "reg.21"}]
    end

    test "several markup records: of one effect when every note names it" do
      id = "key-" <> String.duplicate("a", 32)

      record = fn ref, note ->
        {id, "reg.21",
         [
           %Claim{source: :markup, attribute: :operation, value: :substituted, ref: ref},
           %Claim{source: :markup, attribute: :note, value: note, ref: ref}
         ]}
      end

      feed = feed(id, "reg.21", :substituted, [])

      assert causes([feed, record.("m1", id), record.("m2", id)]) ==
               [{"several markup records of one effect", "reg.21"}]

      assert causes([feed, record.("m1", id), record.("m2", "c000002")]) ==
               [{"several markup records", "reg.21"}]
    end

    test "two law-text records of one change: the feed naming both" do
      repeal = fn key -> text(key, "s.117", :repealed) end
      feed = feed("key-a", "s.117", :repealed, ["s.87", "sch.8"])

      assert causes([repeal.("#{@by}:section-87"), repeal.("#{@by}:schedule-8"), feed]) ==
               [{"two law-text records the feed names together", "s.117"}]
    end

    test "legislation.gov.uk's feed and markup unlike: the operations named" do
      assert causes([
               feed("key-a", "s.273(1)", :renumbered, []),
               markup("key-a", "s.273(1)", :inserted)
             ]) == [{"operations differ in legislation.gov.uk: inserted/renumbered", "s.273(1)"}]
    end

    test "the law's commencement on another day than legislation.gov.uk's date" do
      assert causes([
               text(@key, "reg.21", :substituted, ~D[2019-01-01]),
               feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"])
             ]) == [{"same amending provision, same operation, dates differ", "reg.21"}]
    end

    test "a value conflict on the operation" do
      assert causes([
               text(@key, "reg.21", :repealed),
               feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"])
             ]) == [{"operation differs", "reg.21"}]
    end
  end

  describe "split risk" do
    test "the law's text left beside legislation.gov.uk's likely same event" do
      assert causes([
               text(@key, "reg.21", :substituted),
               feed("key-a", "reg.21", :substituted, []),
               feed("key-b", "reg.21", :substituted, [])
             ]) == [{"unjoined", "reg.21"}]
    end

    test "a law-text copy on a new paragraph below the provision its key joined, left apart" do
      key = "#{@by}:schedule-21-paragraph-34"
      claim = fn s, at, v -> %Claim{source: s, attribute: at, value: v, ref: key} end

      parent = %Change{
        key: "key-a",
        target: "s.271(6)",
        aliases: ["key-a", key],
        claims: [claim.(:feed, :operation, :substituted), claim.(:feed, :by, @by)]
      }

      copy = %Change{
        key: key,
        target: "s.271(6)(a)",
        aliases: [key],
        claims: [claim.(:law_text, :operation, :inserted), claim.(:law_text, :by, @by)]
      }

      found =
        @law
        |> MergeGate.entries(Enum.map([parent, copy], &Evidence.resolve(&1, nil)))
        |> Enum.map(&{&1.cause, &1.target})

      assert {"law-text copy apart from its joined event", "s.271(6)(a)"} in found
    end

    test "a markup-only change with nothing beside it" do
      assert causes([markup("d29p11431", "reg.21", :substituted)]) ==
               [{"markup alone", "reg.21"}]
    end
  end

  describe "spread keys" do
    test "a feed effect over a range is legislation.gov.uk's own" do
      changes = merged(for n <- 1..4, do: feed("key-a", "reg.#{n}(1)", :substituted, []))

      assert [%{cause: "spread: legislation.gov.uk's own effect"}] =
               @law |> MergeGate.entries(changes) |> Enum.filter(&(&1.target == nil))
    end
  end

  describe "spread keys, with carried copies" do
    test "a new paragraph carrying the event counts as the feed's own" do
      claim = fn s, at, v -> %Claim{source: s, attribute: at, value: v, ref: "key-a"} end

      fed =
        for n <- 1..4,
            do: %Change{
              key: "key-a",
              target: "reg.#{n}",
              aliases: ["key-a"],
              claims: [claim.(:feed, :operation, :substituted), claim.(:feed, :by, @by)]
            }

      copy = %Change{
        key: "key-a",
        target: "reg.4(b)",
        aliases: ["key-a", @key],
        claims: [
          claim.(:law_text, :operation, :inserted),
          claim.(:law_text, :by, @by),
          claim.(:feed, :placed, "reg.4")
        ]
      }

      assert [%{cause: "spread: legislation.gov.uk's own effect"}] =
               @law
               |> MergeGate.entries(Enum.map([copy | fed], &Evidence.resolve(&1, nil)))
               |> Enum.filter(&(&1.target == nil))
    end
  end

  describe "items and the gate" do
    test "grouped by cause and amending law, status by law then by cause" do
      entries =
        MergeGate.entries(
          @law,
          [
            merged([
              text(@key, "reg.21", :substituted, ~D[2019-01-01]),
              feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"])
            ])
            | merged([
                feed("key-b", "reg.30", :repealed, []),
                markup("key-b", "reg.30", :repealed)
              ])
          ]
          |> List.flatten()
        )

      reviewed = %{
        "same effect id" => "known: by design",
        "same amending provision, same operation, dates differ @ #{@by}" => "check: read"
      }

      items = MergeGate.items(entries, reviewed)

      assert Enum.sort(Enum.map(items, &{&1.shape, &1.law, &1.reach, &1.status})) == [
               {"same amending provision, same operation, dates differ", @by, 1, "check: read"},
               {"same effect id", @by, 1, "known: by design"}
             ]

      refute MergeGate.gate(items).pass?
    end

    test "an operation conflict takes the amending-law reader's status where it named it" do
      entries =
        MergeGate.entries(
          @law,
          merged([
            text(@key, "reg.21", :repealed),
            feed("key-a", "reg.21", :substituted, ["sch.12.para.21(a)"])
          ])
        )

      [item] = MergeGate.items(entries, %{}, fn _ -> "known: the reader's" end)
      assert item.status == "known: the reader's"
      assert MergeGate.gate([item]).pass?
    end
  end
end
