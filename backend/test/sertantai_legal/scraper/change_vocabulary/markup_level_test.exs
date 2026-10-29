defmodule SertantaiLegal.Scraper.ChangeVocabulary.MarkupLevelTest do
  @moduledoc """
  The markup's level and how sure it is (CV-S08 round 3): a change round
  the number is the whole provision; one covering all of the words, the
  number outside, ranks below the feed; legacy markup's Addition claims no
  operation; a heading's own record beside its provision's whole one claims
  no level; an empty id segment names no level.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, Ref}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.Level

  defp claims(xml, target) do
    xml
    |> Markup.read("UK_uksi_2000_1")
    |> Enum.filter(fn {_, t, _} -> t == target end)
    |> Enum.flat_map(&elem(&1, 2))
    |> Map.new(&{&1.attribute, &1.value})
  end

  test "new words round all of a provision, its number outside, are whole only below the feed" do
    xml =
      ~s(<Legislation><P1 id="regulation-3"><Pnumber>3</Pnumber><P1para><Text><Substitution ChangeId="d29p1">The Control of Noise at Work Regulations 2005</Substitution></Text></P1para></P1></Legislation>)

    c = claims(xml, "reg.3")
    assert c[:level_covering] == :provision
    refute Map.has_key?(c, :level)
  end

  test "a legacy Addition places the change but claims no operation" do
    xml =
      ~s(<Legislation><P1 id="regulation-3"><Pnumber><Addition ChangeId="d29p2">3</Addition></Pnumber><P1para><Text><Addition ChangeId="d29p2">None of the provisions shall apply.</Addition></Text></P1para></P1></Legislation>)

    c = claims(xml, "reg.3")
    assert c[:level] == :provision
    refute Map.has_key?(c, :operation)
  end

  test "a heading's own record beside its provision's whole record claims no level" do
    sets = [
      {"key-x", "reg.20", Claim.new(:markup, :level, :provision, "a")},
      {"key-x", "reg.20",
       Claim.new(:markup, :level, :words, "b") ++ Claim.new(:markup, :heading, true, "b")}
    ]

    assert [_, {_, _, heading}] = Level.heading_wrappers(sets)
    refute Enum.any?(heading, &(&1.attribute == :level))
  end

  test "an empty id segment names no level (REACH article-2-6--d)" do
    assert Ref.from_clml("article-2-6--d-i", "UK_eur_2006_1907") == "art.Article 2(6)(d)(i)"
  end
end
