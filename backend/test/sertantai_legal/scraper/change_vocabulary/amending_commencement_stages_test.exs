defmodule SertantaiLegal.Scraper.ChangeVocabulary.AmendingCommencementStagesTest do
  @moduledoc """
  An amending provision brought in by stages carries each stage as read
  (`commencement.stages`), as the feed reader carries a text change's
  (RULES `text-change-carries-its-stages`): a purpose-limited first stage
  is never lost behind the full one (Merchant Shipping Act 1995 Part 9A by
  the Marine Navigation Act 2011: SI 2015/133, for specified purposes from
  5 February 2015, fully from 14 April 2015). The date stays the full
  start's; the Label fold reads the stages.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingCommencement
  alias SertantaiLegal.Scraper.Commencement.Rule

  @act "UK_ukpga_2011_8"
  @order "UK_uksi_2015_133"

  defp rule(source, date, purposes, treatment \\ :order_date),
    do:
      Rule.new(
        commences: @act,
        scope: ["s.1"],
        when: {:date, date},
        purposes: purposes,
        source: %{law: source, ref: "art.2", text: nil},
        treatment: treatment
      )

  defp value(claims, attribute),
    do: Enum.find_value(claims, &if(&1.attribute == attribute, do: &1.value))

  test "a purpose-limited first stage, then the full one: both carried, the date the full start" do
    rules = [
      rule(@order, ~D[2015-02-05], :for_specified_purposes),
      rule(@order, ~D[2015-04-14], nil)
    ]

    claims = AmendingCommencement.claims(rules, "section-1-4", "k")

    assert value(claims, :date) == ~D[2015-04-14]
    assert value(claims, :commenced_by) == @order

    assert value(claims, :stages) == [
             %{
               date: ~D[2015-02-05],
               commenced_by: @order,
               in_force_for: nil,
               qualification: "for_specified_purposes",
               partial: true
             },
             %{
               date: ~D[2015-04-14],
               commenced_by: @order,
               in_force_for: nil,
               qualification: nil,
               partial: false
             }
           ]
  end

  test "a provision brought in on one day carries no stages" do
    claims = AmendingCommencement.claims([rule(@order, ~D[2015-04-14], nil)], "section-1-4", "k")

    assert value(claims, :date) == ~D[2015-04-14]
    assert value(claims, :stages) == nil
  end

  test "partial stages only: carried, with no date" do
    rules = [rule(@order, ~D[2015-02-05], :for_specified_purposes)]
    claims = AmendingCommencement.claims(rules, "section-1-4", "k")

    assert value(claims, :date) == nil

    assert [%{date: ~D[2015-02-05], partial: true}] = value(claims, :stages)
  end
end
