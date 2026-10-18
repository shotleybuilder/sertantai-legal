defmodule SertantaiLegal.Scraper.Commencement.StoreTest do
  @moduledoc "CR-01: the ruleset's table — a source's rules replaced together, a law's rules read back."
  use SertantaiLegal.DataCase, async: false

  alias Mix.Tasks.Lat.Commencement, as: CommencementTask
  alias SertantaiLegal.Scraper.Commencement.{Rule, Store}

  defp rule(commences, source_law, scope, when_),
    do:
      Rule.new(
        commences: commences,
        scope: scope,
        when: when_,
        source: %{law: source_law, ref: "art.2", text: "comes into force on …"},
        treatment: :order_date
      )

  test "write/2 replaces a source's rules; for_law/1 reads the rules commencing a law" do
    a = rule("UK_ukpga_2014_21", "UK_uksi_2017_1", ["s.11"], {:date, ~D[2017-04-01]})

    b = %{
      rule("UK_ukpga_2014_21", "UK_wsi_2019_1", ["s.11"], {:date, ~D[2019-04-01]})
      | territory: "W"
    }

    assert {:ok, 1} = Store.write("UK_uksi_2017_1", [a])
    assert {:ok, 1} = Store.write("UK_wsi_2019_1", [b])

    assert Enum.sort_by(Store.for_law("UK_ukpga_2014_21"), &Date.to_iso8601(elem(&1.when, 1))) ==
             [a, b]

    # a re-read of a source replaces only its own rules
    a2 = rule("UK_ukpga_2014_21", "UK_uksi_2017_1", ["s.12"], {:date, ~D[2017-04-01]})
    assert {:ok, 1} = Store.write("UK_uksi_2017_1", [a2])
    assert MapSet.new(Store.for_law("UK_ukpga_2014_21")) == MapSet.new([a2, b])
  end

  test "a source's rules must all come from it" do
    assert_raise ArgumentError, fn ->
      Store.write("UK_uksi_2017_1", [rule("UK_ukpga_2014_21", "UK_wsi_2019_1", :all, :unread)])
    end
  end

  test "mix lat.commencement prints a law's rules, one line each, by source" do
    Store.write("UK_uksi_2017_1", [
      rule("UK_ukpga_2014_21", "UK_uksi_2017_1", ["s.11"], {:date, ~D[2017-04-01]})
    ])

    Mix.shell(Mix.Shell.Process)

    CommencementTask.run(["--law", "UK_ukpga_2014_21"])
    assert_received {:mix_shell, :info, ["UK_ukpga_2014_21: 1 rule(s)"]}
    assert_received {:mix_shell, :info, ["\n  from UK_uksi_2017_1"]}

    assert_received {:mix_shell, :info,
                     [
                       "    s.11 — 2017-04-01 — everywhere, fully — order_date — UK_uksi_2017_1 art.2: “comes into force on …”"
                     ]}
  after
    Mix.shell(Mix.Shell.IO)
  end
end
