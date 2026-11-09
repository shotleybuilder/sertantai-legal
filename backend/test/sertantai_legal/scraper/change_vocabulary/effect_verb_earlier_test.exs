defmodule SertantaiLegal.Scraper.ChangeVocabulary.EffectVerbEarlierTest do
  @moduledoc """
  Environmental Protection: Feed reader, Decision 2: an amendment to an
  earlier amending law reads the same whether the feed writes "… in earlier
  amending provision S.I. N/N" or names the law straight after ("… in
  earlier amending S.S.I. 2019/103, reg. 10"): no operation on this law's
  text, marked `earlier_amendment`.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.EffectVerb

  @long "words substituted in earlier amending provision S.I. 2019/758, Sch. 2"

  @short [
    "words substituted in earlier amending S.S.I. 2019/103, reg. 10",
    "words omitted in earlier amending S.I. 2018/1338, reg. 9",
    "inserted in earlier amending S.I. 2019/720, Sch. 2 para. 15(b)",
    "amendment to earlier affecting SI 2019/1 Sch. 2 para. 3",
    "amendment to earlier affecting legislation S.I. 2019/1, reg. 7A",
    "words substituted in earlier amending S.R. 2019/12, reg. 4"
  ]

  test "the long form: no operation, an earlier amendment" do
    assert EffectVerb.kind(@long) == "other"
    assert EffectVerb.earlier_amendment?(@long)
  end

  test "the short form, naming the law: read as the long form" do
    for t <- @short do
      assert EffectVerb.kind(t) == "other", t
      assert EffectVerb.earlier_amendment?(t), t
    end
  end

  test "a plain change, or one to an earlier commencing order, is not an earlier amendment" do
    assert EffectVerb.kind("words substituted") == "substituted"
    refute EffectVerb.earlier_amendment?("words substituted")
    refute EffectVerb.earlier_amendment?("amendment to earlier commencing S.I. 2015/841, art. 7")
    refute EffectVerb.earlier_amendment?("revocation of earlier amending provision S.I. 2019/1")
  end
end
