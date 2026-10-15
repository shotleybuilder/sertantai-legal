defmodule SertantaiLegal.Scraper.LabelVersionTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.{LabelVersion, ParserVersion}

  test "the current version is 12 hex characters" do
    assert LabelVersion.current() =~ ~r/^[0-9a-f]{12}$/
  end

  test "it covers the collectors, the amending-law readers and the projection" do
    files = LabelVersion.files()

    for f <- ~w(
          lib/sertantai_legal/scraper/change_collector.ex
          lib/sertantai_legal/scraper/change_collector/feed.ex
          lib/sertantai_legal/scraper/amending_law/target.ex
          lib/sertantai_legal/scraper/label_projection.ex
          lib/sertantai_legal/scraper/label_timeline.ex
          lib/sertantai_legal/scraper/label_refresh.ex
          mix.lock
        ),
        do: assert(f in files, f)

    assert Enum.all?(files, &File.exists?/1)
  end

  test "it is a different version from the parser's" do
    refute LabelVersion.current() == ParserVersion.current()
  end
end
