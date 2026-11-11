defmodule SertantaiLegal.Scraper.ChangeVocabulary.ShowTest do
  @moduledoc """
  `mix lat.vocabulary --show`'s debug view, read outside the task
  (Environmental Protection: Measures, the parked inline reads): the
  changes reaching a provision, and the labels stored for it today.
  """
  use SertantaiLegal.DataCase, async: true

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Show}

  test "reaching: the changes on the provision, the whole law, or an ancestor" do
    changes =
      for t <- ["s.1(4)(a)", "*", "s.1", "s.1(4)", "s.2", "s.1(4)(b)"],
          do: %Change{key: t, target: t}

    assert changes |> Show.reaching("s.1(4)(a)") |> Enum.map(& &1.target) ==
             ["s.1(4)(a)", "*", "s.1", "s.1(4)"]
  end

  test "stored: the provision's stored periods, in order, as the scoreboard prints them" do
    row = fn sid, from, to ->
      %{
        id: Ecto.UUID.bingenerate(),
        law_name: "UK_uksi_2099_5",
        section_id: "UK_uksi_2099_5:" <> sid,
        valid_from: from,
        valid_to: to,
        status: "in_force",
        in_force_from: from,
        changed_by: "UK_uksi_2099_6",
        territory: "E+W",
        change_ids: [],
        code_version: "x",
        built_at: ~N[2099-01-01 00:00:00]
      }
    end

    Repo.insert_all("lat_label_timeline", [
      row.("reg.1", ~D[2099-03-01], nil),
      row.("reg.1", ~D[2099-01-01], ~D[2099-03-01]),
      row.("reg.2", ~D[2099-01-01], nil)
    ])

    assert [first, _] = Show.stored("UK_uksi_2099_5", "reg.1")

    assert first == %{
             valid_from: ~D[2099-01-01],
             valid_to: ~D[2099-03-01],
             status: "in_force",
             in_force_from: ~D[2099-01-01],
             changed_by: "UK_uksi_2099_6",
             territory: "E+W"
           }

    assert Show.stored("UK_uksi_2099_5", "reg.9") == []
  end
end
