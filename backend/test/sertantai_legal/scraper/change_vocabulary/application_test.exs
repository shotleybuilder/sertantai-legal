defmodule SertantaiLegal.Scraper.ChangeVocabulary.ApplicationTest do
  @moduledoc """
  C6 (Jason 2026-10-21): a law's own application clause sets territory over
  its extent. SI 2012/3038 reg.1A (trimmed real wording): "From 1st January
  2021 these Regulations apply in Northern Ireland only, …".
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary

  @xml ~S"""
  <Legislation RestrictExtent="E+W+S+N.I."><Secondary><Body>
  <P1 id="regulation-1A"><P1para><Text>From 1st January 2021 these Regulations apply in Northern Ireland only, in relation to any emissions created on or after that date, from a regulated activity at an installation.</Text></P1para></P1>
  <P1 id="regulation-2"><P1para><Text>In these Regulations “emissions” means the release of greenhouse gases.</Text></P1para></P1>
  </Body></Secondary><Commentaries/></Legislation>
  """

  defp labels(provisions) do
    "UK_uksi_2012_3038"
    |> ChangeVocabulary.labels(@xml, [], provisions)
    |> Map.new(fn {id, ps} ->
      {id, Enum.map(ps, &Map.take(&1, [:valid_from, :territory, :in_force_from]))}
    end)
  end

  test "every provision applies in NI from the clause's date; not a new version" do
    l = labels(%{"reg.2" => %{extent: "E+W+S+NI", start: ~D[2012-12-28]}})

    assert l["reg.2"] == [
             %{valid_from: ~D[2012-12-28], territory: "E+W+S+NI", in_force_from: ~D[2012-12-28]},
             %{valid_from: ~D[2021-01-01], territory: "NI", in_force_from: ~D[2012-12-28]}
           ]
  end

  test "the provision holding the clause applies there from its own start" do
    l = labels(%{"reg.1A" => %{extent: "E+W+S+NI", start: ~D[2020-12-31]}})

    assert l["reg.1A"] == [
             %{valid_from: ~D[2020-12-31], territory: "NI", in_force_from: ~D[2020-12-31]}
           ]
  end
end
