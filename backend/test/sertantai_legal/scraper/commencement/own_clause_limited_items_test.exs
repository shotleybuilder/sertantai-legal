defmodule SertantaiLegal.Scraper.Commencement.OwnClauseLimitedItemsTest do
  @moduledoc """
  A commencement list's item naming provisions or Parts with a limiting
  clause of its own ("any provision of Parts 1 to 7 which— confers a power
  to make regulations", "so far as it … affects the exercise of such a
  power") is partly in on the statement's day, never fully: the Agriculture
  Act 2020 s.57(1). The lead-in and the plain items stay full.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.OwnClause
  alias SertantaiLegal.Scraper.LawStart.ListItems

  @law "UK_ukpga_2020_21"
  @passed ~D[2020-11-11]

  defp row(sid, text, part), do: %{section_id: "#{@law}:#{sid}", text: text, part: part}

  defp rows,
    do: [
      row("s.1", "…", "1"),
      row("s.17", "…", "2"),
      row("s.18", "…", "2"),
      row("s.34", "…", "4"),
      row("s.52", "…", "8"),
      row("s.53", "…", "8"),
      row(
        "s.57(1)",
        "The following provisions come into force on the day on which this Act is passed—",
        "8"
      ),
      row("s.57(1)(a)", "sections 17 and 18;", "8"),
      row("s.57(1)(b)", "any provision of Parts 1 to 7 which—", "8"),
      row("s.57(1)(b)(i)", "confers a power to make regulations, or", "8"),
      row(
        "s.57(1)(b)(ii)",
        "modifies legislation so as to confer a power to make regulations or a power to make an order by statutory instrument;",
        "8"
      ),
      row(
        "s.57(1)(c)",
        "any other provision of those Parts so far as it, or a modification of legislation it makes, affects the exercise of such a power (for example by defining an expression used in the provision conferring it);",
        "8"
      ),
      row("s.57(1)(d)", "this Part, apart from section 52 and Schedule 7.", "8")
    ]

  defp rules,
    do:
      OwnClause.rules(@law, %{
        type_code: "ukpga",
        rows: rows(),
        made: @passed,
        clml_head: nil,
        lrt_date: nil
      })
      |> Enum.filter(&(&1.source.ref == "s.57(1)" and is_list(&1.scope)))

  describe "the Agriculture Act 2020 s.57(1)" do
    test "(a) and (d) are full: sections 17 and 18, and this Part apart from section 52" do
      assert [full] = Enum.filter(rules(), &(&1.treatment == :provision_dated))
      assert full.when == {:date, @passed}
      assert full.purposes == nil
      assert "s.17" in full.scope and "s.18" in full.scope and "pt.8" in full.scope
      assert "s.52" in full.except
      refute Enum.any?(full.scope, &(&1 in ~w(pt.1 pt.2 pt.3 pt.4 pt.5 pt.6 pt.7)))
    end

    test "(b) and (c) are for some purposes: Parts 1 to 7, partly, on the same day" do
      assert [partly] = Enum.filter(rules(), &(&1.treatment == :provision_qualified))
      assert partly.when == {:date, @passed}
      assert partly.purposes != nil
      # (the Parts the rows hold)
      assert partly.scope == ~w(pt.1 pt.2 pt.4)
    end
  end

  describe "ListItems.read/1: an item's limiting clause" do
    test "a relative clause on the provisions named, its items below it" do
      for item <- [
            "any provision of Parts 1 to 7 which—",
            "any provision of Part 2 which confers a power to make regulations",
            "the provisions of Chapter 3 that modify legislation so as to confer a power"
          ] do
        assert %{plain: "", qualified: ^item} = ListItems.read(item)
      end
    end

    test "so far as, in so far as, for the purposes of, to the extent that" do
      for item <- [
            "Part 3 so far as it confers power to make regulations",
            "Part 3 in so far as it relates to Wales",
            "Part 3 for the purposes of making regulations",
            "Part 3 to the extent that it confers a power"
          ] do
        assert %{plain: "", qualified: ^item} = ListItems.read(item)
      end
    end

    test "a plain item, and a heading in brackets using \"which\", stay full" do
      assert %{plain: "sections 17 and 18", qualified: ""} = ListItems.read("sections 17 and 18")

      assert %{qualified: ""} =
               ListItems.read("section 9 (land which is subject to a tenancy)")

      assert %{plain: "this Part", excepted: "section 52 and Schedule 7.", qualified: ""} =
               ListItems.read("this Part, apart from section 52 and Schedule 7.")
    end
  end
end
