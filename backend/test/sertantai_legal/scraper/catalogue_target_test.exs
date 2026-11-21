defmodule SertantaiLegal.Scraper.CatalogueTargetTest do
  @moduledoc "A catalogue dry run never writes the fixtures."
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.CatalogueTarget, as: Target

  @fixtures "test/fixtures/order_patterns"
  @scratch "data/reports/commencement-reader/dry-run/order_patterns"

  test "a dry run writes to scratch and reads the fixtures' held review" do
    target = Target.dirs([], @fixtures, @scratch)

    assert target == %{write: @scratch, held: @fixtures, dry_run?: true}
    assert Target.notice(target) =~ "the fixtures are untouched"
  end

  test "--accept writes the fixtures; --out writes and reads its own directory" do
    assert Target.dirs([accept: true], @fixtures, @scratch) ==
             %{write: @fixtures, held: @fixtures, dry_run?: false}

    assert Target.dirs([out: "/tmp/x", accept: true], @fixtures, @scratch) ==
             %{write: "/tmp/x", held: "/tmp/x", dry_run?: false}
  end
end
