defmodule SertantaiLegal.Scraper.ChangeVocabulary.ExpiryTest do
  @moduledoc """
  A law's own sunset and the orders continuing it (CV-04; primary text):
  Coronavirus Act 2020 s.89 (trimmed real wording) and SR 2023/140 art.2.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Expiry

  @act ~S"""
  <Legislation RestrictExtent="E+W+S+N.I."><Primary><Body>
  <Part id="part-1"><P1 id="section-8"><P1para><Text>Schedule 7 makes provision for emergency volunteering leave.</Text></P1para></P1>
  <P1 id="section-62"><P1para><Text>Schedule 25 contains powers to postpone elections.</Text></P1para></P1>
  <P1 id="section-78"><P1para><Text>The relevant national authority may by regulations make provision relating to local authority meetings.</Text></P1para></P1></Part>
  <Part id="part-2"><P1 id="section-89"><P1para>
  <P2 id="section-89-1"><P2para><Text>This Act expires at the end of the period of 2 years beginning with the day on which it is passed, subject to subsection (2) and section 90.</Text></P2para></P2>
  <P2 id="section-89-2"><P2para><Text>Subsection (1) does not apply to—</Text>
  <P3 id="section-89-2-i"><P3para><Text>sections 59 to 70;</Text></P3para></P3>
  <P3 id="section-89-2-m"><P3para><Text>this Part;</Text></P3para></P3>
  <P3 id="section-89-2-n"><P3para><Text>Parts 2 to 5 of Schedule 7, and section 8 so far as relating to those Parts;</Text></P3para></P3></P2para></P2>
  </P1para></P1></Part>
  </Body></Primary></Legislation>
  """

  @order "Section 78 of the Coronavirus Act 2020 does not expire at the time when it would otherwise expire and expires instead on 24th March 2024."

  setup do
    sets =
      Expiry.read(@act, "UK_ukpga_2020_7", ~D[2020-03-25], "Coronavirus Act 2020", [
        %{law: "UK_nisr_2023_140", text: @order, territory: "NI"}
      ])

    %{
      by_target:
        Enum.group_by(sets, &elem(&1, 1), fn {_k, _t, claims} ->
          Map.new(claims, &{&1.attribute, &1.value})
        end)
    }
  end

  test "the sunset: every section at the end of the period, except those listed (wholly, or so far as stated)",
       %{by_target: t} do
    # sections 59 to 70; this Part (s.89); section 8 so far as relating to Sch. 7 Pts 2-5
    refute Map.has_key?(t, "s.62")
    refute Map.has_key?(t, "s.89")
    assert [%{operation: :repealed_in_part, date: ~D[2022-03-25]}] = t["s.8"]
  end

  test "a continuation order moves a territory's expiry; the sunset takes the rest", %{
    by_target: t
  } do
    assert Enum.sort_by(t["s.78"], & &1.date, Date) == [
             %{
               operation: :repealed,
               level: :provision,
               date: ~D[2022-03-25],
               territory: "E+W+S",
               by: "UK_ukpga_2020_7",
               clause: "s.89(1)"
             },
             %{
               operation: :repealed,
               level: :provision,
               date: ~D[2024-03-25],
               territory: "NI",
               by: "UK_ukpga_2020_7",
               clause: "UK_nisr_2023_140"
             }
           ]
  end
end
