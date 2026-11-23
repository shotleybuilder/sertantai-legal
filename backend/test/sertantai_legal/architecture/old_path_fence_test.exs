defmodule SertantaiLegal.Architecture.OldPathFenceTest do
  @moduledoc """
  The new path stands apart from the old label path (Commencement reader
  decouple, 2026-11-23):

  - none of its stamps holds the old collector or the old dater
    (`Amendment.Collect`, `Commencement.Amending`, `ChangeCollector`), so an
    old-path edit stales no build, fold or reading;
  - none of its modules reads the old register, `lat_change_log`.

  Both go when the old path retires (DATA-ARCHITECTURE, "When every family
  has switched"). `LabelVersion` is the old path's stamp, so it is not
  checked.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion, as: ExtentVersion
  alias SertantaiLegal.Scraper.ChangeVocabulary.{FoldVersion, Version}
  alias SertantaiLegal.Scraper.Commencement.ReadVersion

  @old ~w(
    lib/sertantai_legal/scraper/commencement/amending.ex
    lib/sertantai_legal/scraper/amendment/collect.ex
    lib/sertantai_legal/scraper/change_collector.ex
  )

  defp old?(f),
    do: f in @old or String.starts_with?(f, "lib/sertantai_legal/scraper/change_collector/")

  for v <- [
        Version,
        FoldVersion,
        ReadVersion.Clause,
        ReadVersion.Orders,
        ReadVersion.Effects,
        ExtentVersion
      ] do
    test "#{inspect(v)} holds none of the old collector or dater" do
      held = for f <- unquote(v).files(), f = Path.relative_to_cwd(f), old?(f), do: f
      assert held == []
    end
  end

  test "no new-path module reads the old register" do
    files =
      Path.wildcard(
        "lib/sertantai_legal/scraper/{change_vocabulary,commencement,step_procedures}/**/*.ex"
      ) ++
        ["lib/mix/tasks/lat.commencement.ex"]

    reading = for f <- files, File.read!(f) =~ "lat_change_log", do: f
    assert reading == []
  end
end
