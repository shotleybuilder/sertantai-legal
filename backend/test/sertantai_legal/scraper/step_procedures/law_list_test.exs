defmodule SertantaiLegal.Scraper.StepProcedures.LawListTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.StepProcedures.LawList

  test "a comma list: blanks and repeats go" do
    assert LawList.parse("A,,B,A, C") == ~w(A B C)
  end

  @tag :tmp_dir
  test "a file with no final newline keeps its last law", %{tmp_dir: dir} do
    path = Path.join(dir, "laws.txt")
    File.write!(path, "UK_uksi_2099_1\nUK_uksi_2099_2\r\n\nUK_uksi_2099_3")
    assert LawList.parse("@" <> path) == ~w(UK_uksi_2099_1 UK_uksi_2099_2 UK_uksi_2099_3)

    File.write!(path, "UK_uksi_2099_1\nUK_uksi_2099_3\n")
    assert LawList.parse("@" <> path) == ~w(UK_uksi_2099_1 UK_uksi_2099_3)
  end
end
