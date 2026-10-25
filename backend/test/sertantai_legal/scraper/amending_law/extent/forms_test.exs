defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.FormsTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Forms

  @forms [
    extends: "Subject to the following provisions, this Act extends to England and Wales only.",
    extends_and:
      "The provisions of this Act extend to England and Wales and, except as mentioned below, to Northern Ireland",
    extends_exc:
      "This Act extends to the whole of the United Kingdom, except for Part 1, which extends to England and Wales only",
    cited_list:
      "These Regulations— (a) may be cited as the X Regulations; (b) come into force on 1st April; and (c) extend to Scotland only",
    named: "Sections 107 and 116A of this Act extend to Scotland only",
    amendments_same:
      "The amendments and repeals in Schedules 20 and 21 have the same extent as the enactments to which they refer",
    extends_except:
      "This Act shall extend to Northern Ireland with the exception of— (a) the provisions of Part 1",
    only_following:
      "Only the following provisions of this Act (together with this section) extend to Northern Ireland, namely— section 3(5) to (8); Part V",
    amendments_where:
      "Where any enactment amended or repealed by this Act extends to any part of the United Kingdom, the amendment or repeal extends to that part",
    except_list:
      "This Act, except— (a) section 1; and (b) section 2, does not extend to Northern Ireland",
    part_not: "Part III, except section 75 and Schedule 7, does not extend to Scotland",
    not_extends: "Nothing in this Act extends to Scotland or Northern Ireland",
    heading: "The following extend also to Scotland— sections 1 to 54"
  ]

  for {form, sentence} <- @forms do
    test "#{form}: #{sentence}" do
      assert Regex.match?(apply(Forms, unquote(form), []), unquote(sentence))
    end
  end

  test "the subject is the law speaking of itself, never of another law" do
    re = Regex.compile!(Forms.subject(), "iu")
    assert "These Regulations extend" =~ re
    refute "in this Act" =~ re
  end
end
