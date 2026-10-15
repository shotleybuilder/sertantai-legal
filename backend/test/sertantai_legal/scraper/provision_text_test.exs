defmodule SertantaiLegal.Scraper.ProvisionTextTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ProvisionText

  defp parse(text), do: ProvisionText.parse(text)

  describe "provisions" do
    test "one provision, with its brackets kept as written" do
      assert parse("s. 27ZA") == {:ok, [{:provision, "section", "27ZA", [], nil}]}
      assert parse("reg. 9(8)") == {:ok, [{:provision, "regulation", "9", ["8"], nil}]}
      assert parse("s. 44(4A)") == {:ok, [{:provision, "section", "44", ["4A"], nil}]}
      assert parse("art. 3(1)(a)") == {:ok, [{:provision, "article", "3", ["1", "a"], nil}]}
      assert parse("rule 5") == {:ok, [{:provision, "rule", "5", [], nil}]}
    end

    test "a range, spaced or not (\"s. 50 - 55\")" do
      assert parse("ss. 11C-11H") == {:ok, [{:range, "section", "11C", "11H"}]}
      assert parse("s. 50 - 55") == {:ok, [{:range, "section", "50", "55"}]}
    end

    test "a bracket range under one parent (\"s. 33(1)(e)-(h)\")" do
      assert parse("s. 33(1)(e)-(h)") ==
               {:ok, [{:provision, "section", "33", ["1", "e"], "h"}]}
    end

    test "a list: more numbers, or brackets after a space continuing the provision" do
      assert parse("s. 27I 27J") ==
               {:ok,
                [{:provision, "section", "27I", [], nil}, {:provision, "section", "27J", [], nil}]}

      assert parse("s. 12(8) (8A)") ==
               {:ok,
                [
                  {:provision, "section", "12", ["8"], nil},
                  {:provision, "section", "12", ["8A"], nil}
                ]}

      assert parse("s. 32 - 37 39") ==
               {:ok, [{:range, "section", "32", "37"}, {:provision, "section", "39", [], nil}]}
    end

    test "brackets with no space between them are a path; the resolver tries each as a list when the path isn't held" do
      assert parse("s. 36(1)(2)") == {:ok, [{:provision, "section", "36", ["1", "2"], nil}]}
    end

    test "commas and \"and\" separate items; a trailing qualifier or definition is dropped" do
      assert parse("s. 5, 6 and 9") ==
               {:ok,
                [
                  {:provision, "section", "5", [], nil},
                  {:provision, "section", "6", [], nil},
                  {:provision, "section", "9", [], nil}
                ]}

      assert parse("s. 65-95 (Pt. 2)") == {:ok, [{:range, "section", "65", "95"}]}

      assert parse(~s[s. 53(1) defn. of "employer"]) ==
               {:ok, [{:provision, "section", "53", ["1"], nil}]}
    end
  end

  describe "containers and headings" do
    test "a Part, a Chapter in a Part, a Schedule, a Schedule paragraph" do
      assert parse("Pt. 2A") == {:ok, [{:part, "2A", nil}]}
      assert parse("Pt. 2 Ch. 3") == {:ok, [{:part, "2", "3"}]}
      assert parse("Sch. 2") == {:ok, [{:schedule, "2", nil}]}
      assert parse("Sch. 2 para. 7") == {:ok, [{:schedule, "2", "7"}]}
    end

    test "\"cross-heading\" is the container the refs name; with provisions, both" do
      assert parse("cross-heading") == {:ok, [:heading]}

      assert parse("s. 27ZA and cross-heading") ==
               {:ok, [{:provision, "section", "27ZA", [], nil}, :heading]}

      assert parse("ss. 11C-11H and cross-heading") ==
               {:ok, [{:range, "section", "11C", "11H"}, :heading]}
    end

    test "\"s. 81 cross-heading\" is the heading only" do
      assert parse("s. 81 cross-heading") == {:ok, [:heading]}
    end

    test "a provision's or Part's heading, sidenote or title is that element alone" do
      assert parse("s. 81 heading") == {:ok, [{:element, "section", "81"}]}
      assert parse("s. 81 sidenote") == {:ok, [{:element, "section", "81"}]}
      assert parse("Pt. 2 heading") == {:ok, [{:part_element, "2", nil}]}
    end

    test "the whole instrument" do
      assert parse("Act") == {:ok, [:whole]}
      assert parse("Regulations") == {:ok, [:whole]}
    end
  end

  test "text it can't read is an error, never a guess" do
    assert parse("word") == :error
    assert parse("Art. 2 para. 1 Point (a)") == :error
    assert parse("s. 5(1) and word") == :error
    assert parse("") == :error
    assert parse(nil) == :error
  end
end
