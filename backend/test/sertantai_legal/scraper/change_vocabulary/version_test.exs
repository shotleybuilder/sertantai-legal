defmodule SertantaiLegal.Scraper.ChangeVocabulary.VersionTest do
  @moduledoc """
  The build's version covers what a build reads, and only that
  (Maritime Safety: Store and build): a measure or a step's check is never
  read by a build, so changing one leaves stored changes current.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Version

  defp files, do: Enum.map(Version.files(), &Path.relative_to_cwd/1)

  test "no measures module is in the build's version" do
    assert Enum.filter(files(), &String.contains?(&1, "change_vocabulary/measures/")) == []
  end

  test "the steps' checks that draw samples are not in it" do
    for f <- ~w(
          lib/sertantai_legal/scraper/change_vocabulary/label_strata.ex
          lib/sertantai_legal/scraper/amending_law/extent/check.ex
          lib/sertantai_legal/scraper/amendment/check_sample.ex
          lib/sertantai_legal/scraper/amendment/check_strata.ex
          lib/sertantai_legal/scraper/change_vocabulary/evidence_sample.ex
          lib/sertantai_legal/scraper/change_vocabulary/merge_sample.ex
          lib/sertantai_legal/scraper/change_vocabulary/label_sample.ex
        ),
        do: refute(f in files(), f)
  end

  test "the vocabulary and its readers are" do
    for f <- ~w(
          lib/sertantai_legal/scraper/change_vocabulary.ex
          lib/sertantai_legal/scraper/change_vocabulary/build.ex
          lib/sertantai_legal/scraper/amendment/reader.ex
        ),
        do: assert(f in files(), f)
  end
end
