defmodule SertantaiLegal.Legal.MakingFunnelTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo

  defp law(live, attrs \\ %{}) do
    name = "UK_uksi_2099_#{System.unique_integer([:positive])}"

    LegalRegister
    |> Ash.Changeset.for_create(
      :create,
      Map.merge(
        %{
          country: "uk",
          name: name,
          title_en: "Test Regulations",
          type_code: "uksi",
          year: 2099,
          number: "1",
          live: live
        },
        attrs
      )
    )
    |> Ash.create!()

    Repo.query!("UPDATE legal_register SET is_making = true WHERE name = $1", [name])
    name
  end

  defp funnel(name) do
    %{rows: [[revoked, action]]} =
      Repo.query!("SELECT revoked, next_action FROM making_funnel WHERE name = $1", [name])

    {revoked, action}
  end

  test "an in-force Making law without LAT is asked to lat_parse" do
    assert funnel(law("✔ In force")) == {false, "lat_parse"}
  end

  test "a revoked law gets no next action: revoked laws are ceiling items, not work" do
    assert funnel(law("❌ Revoked / Repealed / Abolished")) == {true, nil}
  end

  test "a partly revoked law is still in force and keeps its action" do
    assert funnel(law("⭕ Part Revocation / Repeal")) == {false, "lat_parse"}
  end
end
