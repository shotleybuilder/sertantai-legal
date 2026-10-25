defmodule SertantaiLegal.Scraper.Amendment.Reader.TargetsTest do
  @moduledoc "The reader's target helpers (decomposed from Amendment.Reader, run time 2026-10-25)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Text
  alias SertantaiLegal.Scraper.Amendment.Reader.Targets

  defp text(i, opts \\ []), do: struct(Text, [id: "x", instruction: i] ++ opts)

  test "numbers/2: the provision numbers named, a range as 22..25; a title's year never a regulation" do
    assert Targets.numbers(["In section 7(1) for paragraph (b)"], :section) == {:ok, ["7"]}
    assert Targets.numbers(["sections 22 to 25 are repealed"], :section) == {:ok, ["22..25"]}

    assert Targets.numbers(["The Electricity Safety Regulations 2014 are amended"], :regulation) ==
             :none

    assert Targets.numbers(["nothing here", "In regulation 4, omit"], :regulation) == {:ok, ["4"]}
  end

  test "brackets/1: the named brackets, quotes and an after-anchor's last bracket left out" do
    assert Targets.brackets(text("In subsection (5), in paragraph (b), omit “(z)”")) == ["5", "b"]
    assert Targets.brackets(text("after paragraph (2)(b) insert—")) == ["2"]
  end

  test "quoted_targets/2: a quote under the brackets named above its own level (Clean Air Act 1968 s.5(1))" do
    t =
      text(
        "In section 7(1) for paragraph (b) there shall be substituted the following paragraphs:—",
        inserted: [["b"], ["c"]]
      )

    assert Targets.quoted_targets(%{text: t, named: ["1", "b"], numbers: ["7"]}, "s") == [
             "s.7(1)(b)",
             "s.7(1)(c)"
           ]
  end

  test "quoted_targets/2: a quoted section is its own provision (\"For section 99 substitute— 99\")" do
    t = text("For section 99 substitute—", inserted: [["99"], ["99", "1"]])

    assert Targets.quoted_targets(%{text: t, named: [], numbers: ["99"]}, "s") == [
             "s.99",
             "s.99(1)"
           ]
  end

  test "own_number?/2, provision_path?/1, sections_quoted?/1" do
    assert Targets.own_number?("52A", ["52"])
    refute Targets.own_number?("1A", ["142"])
    assert Targets.provision_path?(["47C"])
    refute Targets.provision_path?(["a"])
    assert Targets.sections_quoted?(text("After section 47B insert—"))
    refute Targets.sections_quoted?(text("For section 7(2) substitute—"))
  end

  test "quoting_clause/1: the clause whose quote follows" do
    a = %{text: text("omit “either”;")}
    b = %{text: text("and at the end insert—")}
    assert Targets.quoting_clause([a, b]) == b
  end

  test "named_refs/5 and rule/4" do
    assert Targets.named_refs(text("omit subsection (5)"), {"repealed", "repealed"}, "s", "7", []) ==
             ["s.7"]

    assert "s.7(5)(b)" in Targets.named_refs(text("x"), {"repealed", "repealed"}, "s", "7", [
             "5",
             "b"
           ])

    law = %{law_name: "UK_ukpga_1956_52"}
    assert Targets.rule(law, [], {"repealed", "repealed"}, %{}) == nil

    r =
      Targets.rule(law, ["s.7"], {"repealed", "words repealed"}, %{
        law: "UK_x",
        ref: "s-1",
        text: nil
      })

    assert r.amends == "UK_ukpga_1956_52" and r.level == :words and r.treatment == :instruction
  end
end
