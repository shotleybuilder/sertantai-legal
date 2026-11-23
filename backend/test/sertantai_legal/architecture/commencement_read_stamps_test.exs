defmodule SertantaiLegal.Architecture.CommencementReadStampsTest do
  @moduledoc """
  The commencement reader's three read stamps (`Commencement.ReadVersion`)
  hold exactly the code each read path runs, to the store: so a fix to the
  orders' reader stales only the orders' rules, a fix to the clause reader
  only the clauses', and a tool module beside them nothing. And the build's
  and the extent reader's stamps hold none of the order reader, so an
  orders fix stales no build or extent reading by itself (the Commencement
  reader staleness session). Reach as in `StageSplitTest`.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.ModuleReach
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadVersion, as: ExtentVersion
  alias SertantaiLegal.Scraper.ChangeVocabulary.Version
  alias SertantaiLegal.Scraper.Commencement.{OwnClause, ReadVersion}

  @c "lib/sertantai_legal/scraper/commencement/"
  @io ~w(
    lib/sertantai_legal/repo.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/client.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/clml_store.ex
    lib/sertantai_legal/scraper/lat_staged_parser.ex
    lib/sertantai_legal/scraper/enacted_by/enabling_cache.ex
    lib/sertantai_legal/scraper/source_version.ex
    lib/sertantai_legal/scraper/catalogue_cache.ex
    lib/sertantai_legal/scraper/commencement/clml_rows.ex
  )
  # the store and the stamps themselves: where a read path ends
  @stops @io ++ ReadVersion.boundaries()

  defp files(version), do: version.files() |> Enum.map(&Path.relative_to_cwd/1) |> MapSet.new()

  defp reach(entry),
    do: entry |> ModuleReach.reach(@stops) |> MapSet.difference(MapSet.new(@stops))

  defp diff(a, b), do: a |> MapSet.difference(b) |> Enum.sort()

  for {version, entry} <- [
        {ReadVersion.Clause, ["own_read.ex", "amending_read.ex"]},
        {ReadVersion.Orders, ["order_read.ex"]},
        {ReadVersion.Effects, ["effects.ex"]}
      ] do
    test "#{inspect(version)} is exactly what its read path reaches" do
      reached = reach(Enum.map(unquote(entry), &(@c <> &1)))
      # reached, not stamped: add to its list
      assert diff(reached, files(unquote(version))) == []
      # stamped, never reached: take out of its list
      assert diff(files(unquote(version)), reached) == []
    end
  end

  test "the extent reader's stamp is exactly what its reader reaches" do
    entry = ExtentVersion.files() |> Enum.map(&Path.relative_to_cwd/1)

    own =
      for f <- entry,
          String.starts_with?(f, "lib/sertantai_legal/scraper/amending_law/extent"),
          do: f

    reached = own |> ModuleReach.reach(@io) |> MapSet.difference(MapSet.new(@io))
    assert diff(reached, files(ExtentVersion)) == []
    assert diff(files(ExtentVersion), reached) == []
  end

  test "each treatment is stamped by its own read path" do
    assert Enum.all?(OwnClause.treatments(), &(ReadVersion.group(&1) == :clause))
    assert ReadVersion.group(:order_date) == :orders
    assert ReadVersion.group(:order_schedule) == :orders
    assert ReadVersion.group(:feed_commencement) == :effects
  end

  test "the order reader is in the orders' stamp alone: not the feed's, the build's or the extent reader's" do
    order = [@c <> "order.ex", @c <> "order_read.ex"]
    assert Enum.all?(order, &(&1 in files(ReadVersion.Orders)))

    for v <- [ReadVersion.Effects, Version, ExtentVersion] do
      held = for f <- files(v), f in order or String.starts_with?(f, @c <> "order/"), do: f
      assert {v, held} == {v, []}
    end
  end
end
