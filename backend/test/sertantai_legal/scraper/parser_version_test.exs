defmodule SertantaiLegal.Scraper.ParserVersionTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ParserVersion

  test "the current version is 12 hex characters" do
    assert ParserVersion.current() =~ ~r/^[0-9a-f]{12}$/
  end

  test "it covers the parse, its effect joins and territory, the note parser and the locked deps" do
    files = ParserVersion.files()

    for f <- ~w(
          lib/sertantai_legal/scraper/lat_parser.ex
          lib/sertantai_legal/scraper/lat_parser/walker.ex
          lib/sertantai_legal/scraper/lat_parser/effects.ex
          lib/sertantai_legal/scraper/lat_parser/sort_key.ex
          lib/sertantai_legal/scraper/lat_staged_parser.ex
          lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
          lib/sertantai_legal/scraper/lat_territory.ex
          lib/sertantai_legal/scraper/commentary_parser.ex
          lib/sertantai_legal/legal/lat/transforms.ex
          mix.lock
        ),
        do: assert(f in files, f)

    assert Enum.all?(files, &File.exists?/1)
  end

  test "the digest depends on every file's path and content, not their order" do
    a = [{"a.ex", "x"}, {"b.ex", "y"}]
    assert ParserVersion.digest(a) == ParserVersion.digest(Enum.reverse(a))
    refute ParserVersion.digest(a) == ParserVersion.digest([{"a.ex", "x"}, {"b.ex", "z"}])
    refute ParserVersion.digest(a) == ParserVersion.digest([{"a.ex", "x"}, {"c.ex", "y"}])
  end
end
