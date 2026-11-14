defmodule SertantaiLegal.Scraper.Commencement.AmendingReadTest do
  @moduledoc """
  An amending law's own clause read from the CLML held, as `mix
  lat.commencement --read-amending` writes it and the check's `--fresh`
  previews it: the fresh reading replaces the law's stored own-clause
  rules and keeps every other source's (its feed's records, its orders').
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.{AmendingRead, Rule}

  defp rule(source, treatment, date),
    do:
      Rule.new(
        commences: "UK_uksi_2018_1",
        scope: :all,
        when: {:date, date},
        source: %{law: source, ref: "reg.1", text: "…"},
        treatment: treatment
      )

  test "replace/3: the law's own-clause rules give way to the fresh reading; other sources stay" do
    old = rule("UK_uksi_2018_1", :lrt_metadata, ~D[2018-07-01])
    order = rule("UK_uksi_2018_9", :order_date, ~D[2018-08-01])
    feed = rule("UK_uksi_2018_1", :feed_commencement, ~D[2018-07-02])
    fresh = rule("UK_uksi_2018_1", :clause_date, ~D[2018-07-12])

    assert AmendingRead.replace([old, order, feed], "UK_uksi_2018_1", [fresh]) ==
             [order, feed, fresh]
  end

  test "replace/3: a law not held keeps what is stored" do
    old = rule("UK_uksi_2018_1", :lrt_metadata, ~D[2018-07-01])
    assert AmendingRead.replace([old], "UK_uksi_2018_1", nil) == [old]
  end
end
