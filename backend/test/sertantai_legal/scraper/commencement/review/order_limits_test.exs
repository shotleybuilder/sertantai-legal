defmodule SertantaiLegal.Scraper.Commencement.Review.OrderLimitsTest do
  @moduledoc """
  Fire and OH&S: Labels side by side — the review of stored order rules
  that limit a list, and the ones whose limit follows the last item.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.Commencement.Review.OrderLimits
  alias SertantaiLegal.Scraper.Commencement.Rule

  @last "Sections 89(4), 90(1) and 96(2) of the Act, and section 162(1) of the Act in so far as it relates to paragraph 10(3) of Schedule 15 to the Act,"
  @whole "Sections 89(4), 90(1) and 96(2) of the Act, in so far as they relate to paragraph 10(3) of Schedule 15 to the Act,"

  defp rule(scope, purposes, words, opts \\ []) do
    Rule.new(
      commences: "UK_ukpga_1990_43",
      scope: scope,
      when: Keyword.get(opts, :when, {:date, ~D[1991-01-14]}),
      purposes: purposes,
      source: %{law: "UK_uksi_1991_96", ref: "reg.2", text: "#{words} shall come … #{words}"},
      treatment: Keyword.get(opts, :treatment, :order_date)
    )
  end

  @four ["s.89(4)", "s.90(1)", "s.96(2)", "s.162(1)"]

  test "the limited lists: dated order rules for some purposes over three or more provisions" do
    listed = rule(@four, :in_relation_to, @last)

    rules = [
      listed,
      rule(@four, nil, @last),
      rule(["s.1", "s.2"], :in_relation_to, @last),
      rule(@four, :in_relation_to, @last, when: :unread),
      rule(@four, :in_relation_to, @last, treatment: :provision_dated)
    ]

    assert OrderLimits.limited_lists(rules) == [listed]
  end

  test "a limit after a final \", and <item>\" is flagged, and split where it is that item's" do
    assert OrderLimits.last_item_form?(rule(@four, :in_relation_to, @last))
    assert OrderLimits.splits?(rule(@four, :in_relation_to, @last))
    refute OrderLimits.last_item_form?(rule(@four, :in_relation_to, @whole))
    refute OrderLimits.splits?(rule(@four, :in_relation_to, @whole))
    assert OrderLimits.line(rule(@four, :in_relation_to, @last)) =~ "LAST-ITEM split"
  end

  test "moved: the stored rules a fresh reading no longer gives, and the rules it adds" do
    stored = rule(@four, :in_relation_to, @last)
    full = rule(Enum.take(@four, 3), nil, @last)
    own = rule(["s.162(1)"], :in_relation_to, @last)

    assert {[gone], [_, _]} = OrderLimits.moved([stored], [full, own])
    assert gone == Rule.to_text(stored)
    assert OrderLimits.moved([stored], [stored]) == {[], []}
  end
end
