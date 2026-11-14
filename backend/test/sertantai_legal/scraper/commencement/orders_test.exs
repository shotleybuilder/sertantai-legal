defmodule SertantaiLegal.Scraper.Commencement.OrdersTest do
  @moduledoc "An Act's order list: the title it is searched and matched by, and the orders a re-read takes."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Orders

  describe "act_title/2" do
    test "an SI named after an Act keeps its whole title (SI 2015/1637 is not the Deregulation Act 2015)" do
      title =
        "Deregulation Act 2015 (Health and Safety at Work) (General Duties of Self-Employed Persons) (Consequential Amendments) Order"

      assert Orders.act_title(title, "2015") == title

      assert Orders.act_title("Environment Act 1995 (Isles of Scilly) Order", "1996") ==
               "Environment Act 1995 (Isles of Scilly) Order"
    end

    test "the law's own year at the end is dropped; no title stays nil" do
      assert Orders.act_title("Fire (Scotland) Act 2005", "2005") == "Fire (Scotland) Act"
      assert Orders.act_title(" Fire (Scotland) Act ", "2005") == "Fire (Scotland) Act"
      assert Orders.act_title(nil, "2005") == nil
    end
  end

  describe "candidates/2" do
    test "the cached list and the orders whose rules are stored, each once, sorted" do
      assert Orders.candidates(["UK_uksi_2005_423", "UK_uksi_2004_2173"], ["UK_uksi_2006_1279"]) ==
               ["UK_uksi_2004_2173", "UK_uksi_2005_423", "UK_uksi_2006_1279"]

      assert Orders.candidates(nil, ["UK_uksi_2002_2024", "UK_uksi_2002_2024"]) ==
               ["UK_uksi_2002_2024"]

      assert Orders.candidates(nil, []) == []
    end
  end
end
