defmodule SertantaiLegal.Scraper.ChangeVocabulary.StaleStagesTest do
  @moduledoc "What a switched law's stale labels need in the stage walk (#194)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.StaleStages

  test "the fold's code, the changes folded or its inputs moved: fold again, no build" do
    assert StaleStages.label_action([:fold_version]) == :refold
    assert StaleStages.label_action([:labels_behind_changes, :fold_inputs]) == :refold
  end

  test "parsed or failed since: refresh (build, then fold)" do
    assert StaleStages.label_action([:labels_behind_parse]) == :refresh
    assert StaleStages.label_action([:fold_version, :labels_failed]) == :refresh
  end

  test "the parse itself stale: nothing here mends it" do
    assert StaleStages.label_action([:parser_version]) == :reparse
    assert StaleStages.label_action([:no_parse_event, :fold_version]) == :reparse
  end
end
