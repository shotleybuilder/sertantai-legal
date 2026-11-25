defmodule SertantaiLegal.Architecture.ExtentWriteTest do
  @moduledoc """
  One extent writer (run time 2026-10-26): `extent_rules` are written only
  through `Extent.Write.write_read/3`, which adds an SI's enabling powers
  (else its legislature's competence) to the reading before storing it —
  as `mix lat.extent_check` reads it. The amendment read pass had stored
  the bare reading, wiping 482 laws' powers and competence rows on every
  full pass. The store's own `write/2` and `stamp/1` are called by
  `Extent.Write` alone (split from the store: the Extent reader stamps
  session).
  """
  use ExUnit.Case, async: true

  @lib Path.expand("../../../lib", __DIR__)
  @writers ~w(
    sertantai_legal/scraper/amending_law/extent/store.ex
    sertantai_legal/scraper/amending_law/extent/write.ex
  )

  # the name a file calls the extent store by: Extent.Store in full, or its alias
  defp names(src) do
    aliased =
      cond do
        m = Regex.run(~r/alias\s+[\w.]*AmendingLaw\.Extent\.Store,\s*as:\s*(\w+)/, src) ->
          [Enum.at(m, 1)]

        src =~ ~r/alias\s+[\w.]*AmendingLaw\.Extent\.(?:Store\b|\{[^}]*\bStore\b)/ ->
          ["Store"]

        true ->
          []
      end

    ["Extent\\.Store" | aliased]
  end

  test "nothing but the store writes a bare extent reading" do
    offenders =
      for path <- Path.wildcard(Path.join(@lib, "**/*.ex")),
          rel = Path.relative_to(path, @lib),
          rel not in @writers,
          src = File.read!(path),
          Enum.any?(
            names(src),
            &(src =~ Regex.compile!("(?<![\\w.])#{&1}\\.(?:write|stamp)\\("))
          ),
          do: rel

    assert offenders == []
  end
end
