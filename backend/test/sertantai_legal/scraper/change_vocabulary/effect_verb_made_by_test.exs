defmodule SertantaiLegal.Scraper.ChangeVocabulary.EffectVerbMadeByTest do
  @moduledoc "CV-S09 round 7 (AS): the earlier amending law a text change's feed Type names as making the words (C5)."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.EffectVerb

  test "a text change made by an earlier law, as later amended, names that law" do
    assert EffectVerb.made_by(
             "words inserted by S.I. 2019/720, Sch. 2 para. 15(b) (as substituted)"
           ) ==
             "UK_uksi_2019_720"

    assert EffectVerb.made_by("word substituted by S.R. 2016/427, Sch. 5 (as amended)") ==
             "UK_nisr_2016_427"
  end

  test "a modification, or a plain verb, names none" do
    assert EffectVerb.made_by("applied (with modifications) by S.I. 2019/1 (as amended)") == nil
    assert EffectVerb.made_by("words substituted") == nil
    assert EffectVerb.made_by(nil) == nil
  end
end
