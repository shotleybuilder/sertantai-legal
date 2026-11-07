defmodule SertantaiLegal.Scraper.Checks.ExtentCensusTest do
  @moduledoc """
  The whole-reader census in Elixir (#192): on the frozen run (CV-S05d
  run-07, `test/fixtures/extent_census/run-07/`: its input and every
  law's structure as Python's `finder.Structure` read it), the census and
  the bench give the files the Python wrote, byte for byte, by their
  sha256; the pieces give what `finder.py` and `census.py` give on the
  same words; and the census reaches no module of the extent reader it
  checks.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ModuleReach
  alias SertantaiLegal.Scraper.Checks.ExtentCensus

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.{
    Bench,
    Judge,
    LawCheck,
    Mentions,
    Places,
    ReadingDiff,
    Refs,
    ScopeKind,
    Segments,
    Stored,
    Structure
  }

  @dir "test/fixtures/extent_census/run-07"

  defp fixture(name), do: Path.join(@dir, name) |> File.read!() |> :zlib.gunzip()

  defp sha(iodata), do: :sha256 |> :crypto.hash(iodata) |> Base.encode16(case: :lower)

  defp hashes do
    for line <- @dir |> Path.join("sha256.txt") |> File.read!() |> String.split("\n", trim: true),
        into: %{} do
      [h, name] = String.split(line, ~r/\s+/, parts: 2)
      {name, h}
    end
  end

  describe "run-07, frozen" do
    setup do
      input = fixture("input.jsonl.gz")
      laws = input |> String.split("\n", trim: true) |> Enum.map(&Jason.decode!/1)

      structure =
        "structures.json.gz"
        |> fixture()
        |> Jason.decode!()
        |> Map.new(fn {l, m} -> {l, Structure.from_map(m)} end)

      %{input: input, laws: laws, structure: structure, hashes: hashes()}
    end

    test "the input is run-07's", %{input: input, hashes: h} do
      assert sha(input) == h["input.jsonl"]
    end

    test "sentences, scope, unnamed and stats as census.py wrote them", %{
      laws: laws,
      structure: st,
      hashes: h
    } do
      r = ExtentCensus.run(laws, st)
      assert sha(r.sentences) == h["sentences.tsv"]
      assert sha(r.scope) == h["scope.tsv"]
      assert sha(r.unnamed) == h["unnamed.tsv"]
      assert sha(r.stats) == h["stats.json"]
    end

    test "the bench as bench.py wrote it (5/10)", %{laws: laws, structure: st, hashes: h} do
      text = laws |> Map.new(&{&1["law"], &1}) |> Bench.run(st)
      assert sha(text) == h["bench.txt"]
      assert text =~ "5/10 flagged"
    end
  end

  test "the census reaches no module of the extent reader (finder.py's promise)" do
    {:ok, mods} = :application.get_key(:sertantai_legal, :modules)

    census =
      for m <- mods,
          f = ModuleReach.source(m),
          String.starts_with?(f, "lib/sertantai_legal/scraper/checks/extent_census"),
          not String.ends_with?(f, "/dump.ex"),
          do: f

    reader =
      for f <- ModuleReach.reach(census),
          String.starts_with?(f, "lib/sertantai_legal/scraper/amending_law/"),
          do: f

    assert length(census) >= 12
    assert reader == []
  end

  # a law of six sections, Part 2 holding 3–5 (Chapter 1 holding 3–4), and Schedule 4
  defp st do
    Structure.from_map(%{
      "order" => ~w(s.1 s.2 s.3 s.4 s.5 s.5A s.6 sch.4.para.1 sch.4.para.2),
      "members" => [
        ["part-2", ~w(s.3 s.4 s.5)],
        ["part-2-chapter-1", ~w(s.3 s.4)],
        ["schedule-4", ~w(sch.4.para.1 sch.4.para.2)]
      ]
    })
  end

  describe "the finder (as finder.py)" do
    test "places, with law titles masked" do
      assert Places.code("England and Wales") == "E+W"
      assert Places.code("Great Britain and Northern Ireland") == "E+W+S+NI"
      assert Places.code("the Water (Scotland) Act 1980 extends to Northern Ireland") == "NI"
      assert Places.code("the Countryside") == nil
    end

    test "number lists, continuations and ranges" do
      assert Refs.items_of("1, 2(1), (4) and (5), 7") == [
               {"1", []},
               {"2", ["1"]},
               {"2", ["4"]},
               {"2", ["5"]},
               {"7", []}
             ]

      assert Refs.items_of("3 to 5") == [{:range, {"3", []}, {"5", []}}]

      assert Enum.sort(Refs.sub_range("s.8", ["2", "b"], ["d"])) ==
               ~w[s.8(2)(b) s.8(2)(c) s.8(2)(d)]

      assert Enum.sort(Refs.sub_range("s.8", ["4"], ["6A"])) == ~w[s.8(4) s.8(5) s.8(6) s.8(6A)]
      assert Refs.expand_alpha("II", "IV") == ~w(II III IV)
      assert Refs.expand_alpha("A", "C") == ~w(A C)
    end

    test "element ids as provision refs" do
      assert Enum.map(
               ~w(section-3A regulation-2 schedule-2-paragraph-4 schedule-part-1 schedule-3 schedule-1-part-2-paragraph-3 part-1),
               &Structure.top_ref/1
             ) == ["s.3A", "reg.2", "sch.2.para.4", nil, "sch.3", "sch.1.pt.2.para.3", nil]
    end

    test "a head and its lettered items, the items taking the head's statement" do
      assert [head, a, b] =
               Segments.segments(
                 "The following provisions extend to Scotland— (a) section 3; (b) section 4."
               )

      assert {head.text, head.places, head.item} ==
               {"The following provisions extend to Scotland—", "S", false}

      assert {a.text, a.label, a.places, a.inherited} == {"section 3;", "a", "S", true}
      assert {b.text, b.label} == {"section 4.", "b"}
    end

    test "two statements joined by but" do
      assert [one, two] =
               Segments.segments(
                 "Section 2 extends to England and Wales, but section 3 extends to Scotland only."
               )

      assert {one.text, one.places} == {"Section 2 extends to England and Wales", "E+W"}

      assert {two.text, two.places, two.item} ==
               {"section 3 extends to Scotland only.", "S", true}
    end

    test "mentions: own provisions, a Schedule's paragraph, another law's, excepted, this Part" do
      refs = fn seg, own ->
        seg |> Mentions.mentions(own, st()) |> elem(0) |> Enum.map(&{Enum.sort(&1.refs), &1.kind})
      end

      assert refs.("sections 3 to 5 and Schedule 2 extend to Scotland", "s.9") ==
               [{~w(s.3 s.4 s.5), "section"}, {["sch.2"], "schedule"}]

      assert refs.("paragraph 2(1) of Schedule 4 extends to Wales", "s.9") == [
               {["sch.4.para.2(1)"], "paragraph"}
             ]

      assert refs.("this Part extends to Wales", "s.4") == [{~w(s.3 s.4 s.5), "self"}]
      assert refs.("subsection (2) extends to Scotland", "s.9(1)") == [{["s.9(2)"], "subsection"}]

      {[foreign], _} =
        Mentions.mentions("section 9 of the Water Act 1989 extends to Scotland", "s.9", st())

      assert foreign.foreign and MapSet.size(foreign.refs) == 0

      {[excepted], _} =
        Mentions.mentions("this Act, except section 7, extends to Scotland", "s.9", st())

      assert excepted.excepted
    end
  end

  describe "the census (as census.py)" do
    defp stored,
      do:
        Stored.new(
          %{
            "default" => "E+W",
            "application" => nil,
            "lists" => [%{"kind" => "only", "place" => "S", "refs" => ["s.3", "s.4..s.5"]}],
            "applies" => []
          },
          st()
        )

    test "stored ranges expanded by document order; ancestors" do
      assert [{"only", "S", refs}] = stored().rows
      assert Enum.sort(refs) == ~w(s.3 s.4 s.5)
      assert Stored.ancestors("s.3(1)(a)") == ~w[s.3(1) s.3]
      assert Stored.ancestors("sch.9.pt.2.para.3") == ~w(sch.9.pt.2 sch.9)
    end

    test "a whole-law statement against the default and the application" do
      whole = fn text -> text |> Segments.segments() |> hd() |> Judge.whole(stored()) end
      assert whole.("This Act extends to England and Wales.") == "ok"
      assert whole.("This Act extends to Scotland only.") == "whole_mismatch"
      assert whole.("These Regulations apply in relation to Wales.") == "whole_missing"
    end

    test "an apply statement's kind: territorial, scope or both" do
      kind = fn text -> text |> Segments.segments() |> hd() |> ScopeKind.kind() end
      assert kind.("These Regulations apply in relation to Wales.") == "territorial"
      assert kind.("This regulation applies if the land is in Scotland.") == "scope"
      assert kind.("These Regulations apply to United Kingdom ships in Scotland.") == "both"
    end

    test "a law's sentences judged against its rows" do
      law = %{
        "law" => "UK_x",
        "default" => "E+W",
        "application" => nil,
        "lists" => [%{"kind" => "only", "place" => "S", "refs" => ["s.3", "s.4..s.5"]}],
        "applies" => [],
        "sentences" => [
          %{
            "ref" => "s.9",
            "class" => "list:only:S",
            "s" => "Sections 3 to 5 extend to Scotland only."
          },
          %{"ref" => "s.10", "class" => "x", "s" => "Section 6 extends to Wales."}
        ]
      }

      assert {[nine, ten], []} = LawCheck.check(law, st())

      assert Enum.map(nine.verdicts, &Tuple.delete_at(&1, 2)) == [
               {"ok", "s.3", "S"},
               {"ok", "s.4", "S"},
               {"ok", "s.5", "S"}
             ]

      assert ten.verdicts == [{"missing", "s.6", "Section 6", "W"}]
      assert ExtentCensus.worst(ten.verdicts) == "missing"
      assert ExtentCensus.worst([]) == "none"
    end

    test "the reading diff: rows gone and added, class counts" do
      a = %{
        "default" => "E+W",
        "application" => nil,
        "lists" => [%{"kind" => "unread", "place" => nil, "refs" => ["s.5(5)"]}],
        "applies" => [],
        "sentences" => [%{"class" => "unread:not_read"}]
      }

      b = %{
        a
        | "lists" => [%{"kind" => "not", "place" => "S", "refs" => ["s.5(5)"]}],
          "sentences" => [%{"class" => "list:not:S"}]
      }

      assert ReadingDiff.run(%{"UK_x" => a}, %{"UK_x" => b, "UK_y" => a}) ==
               {"\n2 laws changed of 2\n## UK_x\n  - unread None: s.5(5)\n  + not S: s.5(5)\n  classes list:not:S+1, unread:not_read-1\n## UK_y: added\n",
                2}
    end
  end
end
