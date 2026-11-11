defmodule SertantaiLegal.Scraper.ChangeVocabulary.LabelRulesTest do
  @moduledoc "The switch-over's rules (CV-06): each fault class as a check over a row's periods."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Evidence, LabelRules}

  defp p(from, status, opts \\ []),
    do: %{
      valid_from: from,
      valid_to: Keyword.get(opts, :to),
      status: status,
      in_force_from: nil,
      changed_by: Keyword.get(opts, :by, []),
      territory: Keyword.get(opts, :territory, "E+W+S")
    }

  defp change(op, date, opts \\ []),
    do: %Change{
      key: Keyword.get(opts, :key, "k"),
      target: "s.1",
      resolved: %Evidence.Resolved{
        operation: op,
        level: :provision,
        territory: nil,
        date: date,
        by: Keyword.get(opts, :by),
        retained: false,
        partial: false,
        saved: Keyword.get(opts, :saved, false),
        sources: Keyword.get(opts, :sources, %{})
      }
    }

  @ctx %{
    made: nil,
    law_start: nil,
    eu: false,
    windsor: false,
    made_of: %{},
    existed: &__MODULE__.never/1
  }
  def never(_date), do: false

  defp rules(periods, reaching \\ [], ctx \\ %{}),
    do: periods |> LabelRules.breaches(reaching, Map.merge(@ctx, ctx)) |> Enum.map(&elem(&1, 0))

  test "a period credited to a law before that law was made" do
    assert rules([p(~D[1974-10-01], :in_force, by: ["UK_ukpga_1975_71"])], [], %{
             made_of: %{"UK_ukpga_1975_71" => ~D[1975-11-12]}
           }) == [:before_amender]
  end

  test "a period before its own insertion, nothing showing it was there" do
    assert rules([p(~D[1962-04-01], :in_force)], [change(:inserted, ~D[1973-02-01])]) == [
             :before_insertion
           ]

    assert rules([p(~D[1962-04-01], :in_force)], [change(:inserted, ~D[1973-02-01])], %{
             existed: fn _ -> true end
           }) ==
             []
  end

  test "a later insertion for another version is no breach where its own insertion began it (EPA s.33(10)(a)[S])" do
    own = change(:inserted, ~D[2005-01-21], by: "UK_ssi_2005_22")
    other = change(:inserted, ~D[2006-05-15], by: "UK_uksi_2006_937")

    assert rules([p(~D[2005-01-21], :in_force, territory: "S")], [own, other]) == []
  end

  test "an insertion only legacy markup claims is listed apart, not a breach (HSWA s.30 by EPA 1975)" do
    legacy = change(:inserted, ~D[1975-11-12], key: "d29p3170", sources: %{operation: :markup})
    assert rules([p(~D[1974-07-31], :in_force)], [legacy]) == [:legacy_unconfirmed]
    assert :legacy_unconfirmed in LabelRules.informational()
  end

  test "a UK change to a Windsor law from 2020-12-31 reaching NI" do
    assert rules(
             [p(~D[2020-12-31], :in_force, by: ["UK_uksi_2019_758"], territory: "E+W+S+NI")],
             [],
             %{
               windsor: true
             }
           ) == [:windsor_ni]

    assert rules([p(~D[2020-12-31], :in_force, by: ["UK_uksi_2019_758"])], [], %{windsor: true}) ==
             []
  end

  test "a law made before its start with no prospective period from its making" do
    ctx = %{made: ~D[1997-07-22], law_start: ~D[1998-07-01]}
    assert rules([p(~D[1998-07-01], :in_force)], [], ctx) == [:no_made_period]

    assert rules(
             [p(~D[1997-07-22], :prospective, to: ~D[1998-07-01]), p(~D[1998-07-01], :in_force)],
             [],
             ctx
           ) == []
  end

  test "a repeal its law's text saves, labelled repealed" do
    assert rules(
             [p(~D[1962-04-01], :in_force, to: ~D[1975-01-01]), p(~D[1975-01-01], :repealed)],
             [
               change(:repealed, ~D[1975-01-01], saved: true)
             ]
           ) == [:saved_not_saved]
  end
end
