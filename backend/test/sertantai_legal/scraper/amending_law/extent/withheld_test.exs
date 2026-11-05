defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.WithheldTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Withheld

  @rows %{
    "UK_uksi_2005_881" => %{
      law: "UK_uksi_2005_881",
      withholding: ["reg.2: save that … in relation to Scotland (unread:not_read)"],
      powers_why: nil
    },
    "UK_uksi_1977_445" => %{
      law: "UK_uksi_1977_445",
      withholding: [],
      powers_why: "no powers clause read"
    }
  }

  @changes [
    %{outcome: "bound:law", by: "UK_uksi_2010_1"},
    %{outcome: "none:unread_statement", by: "UK_uksi_2005_881"},
    %{outcome: "none:unread_statement", by: "UK_uksi_2005_881"},
    %{outcome: "none:law_no_powers", by: "UK_uksi_1977_445"},
    %{outcome: "none:same", by: "UK_ukpga_2006_46"}
  ]

  test "one item per cause and amending law, its reach the changes withheld, with its words" do
    items = Withheld.items(@changes, @rows, %{})

    assert [
             %{shape: "none:unread_statement", law: "UK_uksi_2005_881", reach: 2, words: [w]},
             %{
               shape: "none:law_no_powers",
               law: "UK_uksi_1977_445",
               reach: 1,
               words: ["no powers clause read"]
             },
             %{shape: "none:same", law: "UK_ukpga_2006_46", reach: 1}
           ] = Enum.sort_by(items, &(-&1.reach))

    assert w =~ "reg.2"
    refute Enum.any?(items, &(&1.law == "UK_uksi_2010_1"))
  end

  test "a status by law first, then by cause: the gate passes only every one known" do
    reviewed = %{
      "none:same" => "known: by design — the enactment's own extent",
      "none:law_no_powers @ UK_uksi_1977_445" =>
        "known: legislation.gov.uk's introduction has no powers clause",
      "none:unread_statement @ UK_uksi_2005_881" => "fix: reg.2's 'save that' list"
    }

    gate = @changes |> Withheld.items(@rows, reviewed) |> Withheld.gate()
    refute gate.pass?
    assert [%{law: "UK_uksi_2005_881"}] = gate.failing
    assert gate.counts == %{known: 2, fix: 1}

    reviewed =
      Map.put(reviewed, "none:unread_statement @ UK_uksi_2005_881", "known: one-law wording")

    assert (@changes |> Withheld.items(@rows, reviewed) |> Withheld.gate()).pass?
  end
end
