defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.CreditTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.ExtentDoc
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Credit

  @doc_ ExtentDoc.doc(
          "UK_uksi_2016_1142",
          ExtentDoc.p1("article-1", "Words.") <>
            Enum.map_join(2..7, &ExtentDoc.p1("article-#{&1}", "Words."))
        )

  describe "own_refs/3" do
    test "each provision the subject names, this article too" do
      assert Credit.own_refs(
               "This article, articles 6(4) and (5) and 7 extend to England and Wales.",
               "reg.1",
               @doc_
             ) ==
               ["reg.1", "reg.6(4)", "reg.6(5)", "reg.7"]
    end

    test "a mention read as none leaves it unparsed (round 7 NEW-3)" do
      assert Credit.own_refs(
               "Articles 3 to 5 and Part 2 of the Annex extend to England and Wales only.",
               "reg.1",
               @doc_
             ) == :unparsed
    end

    test "an unnumbered Schedule's Part is named (round 13: was unparsed, KL)" do
      assert Credit.own_refs(
               "Articles 3 to 5 and Part 2 of the Schedule extend to England and Wales and Northern Ireland only.",
               "reg.1",
               @doc_
             ) == ["reg.3..reg.5", "sch.pt.2"]
    end

    test "never a lead, a describing bracket, a locator, another law's or a heading" do
      for {s, want} <- [
            {"Subject to section 17(6), an amendment or repeal by this Act of another enactment has the same extent as the enactment amended.",
             []},
            {"Section 114 (power to act in connection with scheme under section 113) extends to England and Wales.",
             ["s.114"]},
            {"Section 82 above (with Schedule 9) extends to Northern Ireland only.",
             ["s.82", "sch.9"]},
            {"Sections 260 to 266 in Part 13 extend also to Scotland.", ["s.260..s.266"]},
            {"Section 2 of the Health Act 2006 extends to Scotland.", []},
            {"The following provisions extend to Wales— section 3;", []}
          ] do
        assert Credit.own_refs(s, "s.9", @doc_) == want, s
      end
    end
  end

  describe "list_read?/6" do
    test "credited only when each provision it names was read" do
      s = "This article, articles 6(4) and (5) and 7 extend to England and Wales."
      read = [{:named, "E+W", ["reg.6(4)", "reg.6(5)", "reg.7"]}]

      refute Credit.list_read?(s, "reg.1", @doc_, read, :named, "E+W")

      assert Credit.list_read?(
               s,
               "reg.1",
               @doc_,
               [{:named, "E+W", ["reg.1" | elem(hd(read), 2)]}],
               :named,
               "E+W"
             )
    end

    test "a range read covers a provision in it; no subject: by kind and place" do
      assert Credit.list_read?(
               "Article 4 extends to Wales.",
               "reg.1",
               @doc_,
               [{:only, "W", ["reg.3..reg.5"]}],
               :only,
               "W"
             )

      assert Credit.list_read?(
               "An amendment made by this Order has the same extent as the enactment amended.",
               "reg.1",
               @doc_,
               [{:same, nil, ["*"]}],
               :same,
               nil
             )
    end
  end
end
