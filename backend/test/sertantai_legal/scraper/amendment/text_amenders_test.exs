defmodule SertantaiLegal.Scraper.Amendment.TextAmendersTest do
  @moduledoc """
  The amending laws of a law's text changes, one definition for the build's
  stale reason (`Store.Inputs`, `:amending_reader`), the step's stale list
  (`StepProcedures.AmendingStale`) and the read pass's feed pointers
  (`ReadPass.feed_pointers/0`): the stored rules' sources, and the feed's
  amending laws on its text effects (`TextEffect`). Until the step
  procedures session the build counted every feed effect but a
  commencement, modifications too, which no read clears (122 pairs on the
  round, 2026-11-26).
  """
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Scraper.Amendment.{Rule, Store, TextAmenders}

  @law "UK_uksi_2099_7031"
  @amender "UK_uksi_2099_7032"

  defp effect(type, affecting), do: %{type: type, affecting: affecting}

  test "the feed's amending laws on its text effects, never a modification or a commencement" do
    effects = [
      effect("substituted", "UK_uksi_2099_1"),
      effect("words inserted", "UK_uksi_2099_2"),
      effect("modified", "UK_uksi_2099_3"),
      effect("applied (with modifications)", "UK_uksi_2099_4"),
      effect("coming into force", "UK_uksi_2099_5"),
      effect("repealed", "EU_2099_6")
    ]

    assert TextAmenders.from_effects(effects) == ["UK_uksi_2099_1", "UK_uksi_2099_2"]
  end

  test "a law's amenders: its stored rules' sources and its feed's" do
    rule =
      Rule.new(
        amends: @law,
        targets: ["reg.2"],
        operation: :repealed,
        level: :provision,
        source: %{law: @amender, ref: "reg.3", text: "Regulation 2 is revoked."},
        treatment: :instruction
      )

    {:ok, 1} = Store.write(@amender, [rule])
    feed = %{@law => [effect("substituted", "UK_uksi_2099_9")]}

    assert TextAmenders.for_laws([@law, "UK_uksi_2099_7033"], &Map.get(feed, &1, [])) == %{
             @law => [@amender, "UK_uksi_2099_9"],
             "UK_uksi_2099_7033" => []
           }
  end
end
