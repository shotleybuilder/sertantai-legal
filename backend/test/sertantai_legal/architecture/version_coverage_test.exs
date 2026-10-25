defmodule SertantaiLegal.Architecture.VersionCoverageTest do
  @moduledoc """
  A version hash (`SourceVersion`) says when stored results are stale, so
  it must cover every module its files reach that shapes what they read —
  else a change to that module leaves stale results looking current
  (run time, 2026-10-25: `ChangeVocabulary.Version` missed the LawStart
  readers). Reach is followed through module references in the compiled
  code; I/O modules (the repo, the HTTP client, the CLML store) are
  allowed, the inputs they serve being fingerprinted on their own.
  """
  use ExUnit.Case, async: true

  @io ~w(
    lib/sertantai_legal/repo.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/client.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/clml_store.ex
  )

  for version <- [
        SertantaiLegal.Scraper.ChangeVocabulary.Version,
        SertantaiLegal.Scraper.Amendment.ReaderVersion
      ] do
    test "#{inspect(version)} covers every module its files reach" do
      covered = unquote(version).files() |> Enum.map(&Path.relative_to_cwd/1) |> MapSet.new()
      missing = covered |> reach() |> MapSet.difference(covered) |> Enum.reject(&(&1 in @io))

      assert missing == [],
             "#{inspect(unquote(version))} misses (add to its patterns, or to @io if it only fetches or stores):\n  " <>
               Enum.join(missing, "\n  ")
    end
  end

  defp reach(files) do
    {:ok, mods} = :application.get_key(:sertantai_legal, :modules)
    by_file = Map.new(mods, &{source(&1), &1})
    walk(MapSet.to_list(files), MapSet.new(), by_file, MapSet.new(mods))
  end

  defp walk([], seen, _by_file, _mods), do: seen

  defp walk([f | rest], seen, by_file, mods) do
    case {MapSet.member?(seen, f), by_file[f]} do
      {false, mod} when mod != nil ->
        walk(refs(mod, mods) ++ rest, MapSet.put(seen, f), by_file, mods)

      _ ->
        walk(rest, seen, by_file, mods)
    end
  end

  # the app modules a module's compiled code names
  defp refs(mod, mods) do
    {:ok, {_, [atoms: atoms]}} = :beam_lib.chunks(:code.which(mod), [:atoms])

    for {_, a} <- atoms,
        MapSet.member?(mods, a),
        f = source(a),
        String.starts_with?(f, "lib/"),
        do: f
  end

  defp source(mod),
    do: mod.module_info(:compile)[:source] |> to_string() |> Path.relative_to_cwd()
end
