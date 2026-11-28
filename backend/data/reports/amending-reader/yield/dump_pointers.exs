# Each feed text effect on a held law, with the reader's own pointers
# (Pointer.refs_in) and the amending law's elements they locate (Locator).
# Nothing written to the DB. Amending-law reader: yield, 2026-11-27.
#   mix run data/reports/amending-reader/yield/dump_pointers.exs OUT.jsonl
alias SertantaiLegal.Repo
alias SertantaiLegal.Scraper.Amendment.{ReadLaw, TextAmenders}
alias SertantaiLegal.Scraper.AmendingLaw.{Locator, Pointer}

[out] = System.argv()
File.rm(out)

laws = Repo.query!("SELECT DISTINCT law_name FROM legal_articles ORDER BY 1").rows |> List.flatten()
IO.puts("#{length(laws)} held laws")

effects = Enum.flat_map(laws, fn law -> for e <- TextAmenders.feed_effects(law), do: {law, e} end)
IO.puts("#{length(effects)} text effects")

effects
|> Enum.group_by(fn {_, e} -> e.affecting end)
|> Enum.with_index(1)
|> Enum.each(fn {{amending, rows}, i} ->
  doc = ReadLaw.doc(amending)

  lines =
    for {law, e} <- rows do
      refs = Pointer.refs_in(e.affecting_provisions)
      ids = if doc, do: refs |> Enum.flat_map(&Locator.ids(doc, &1)) |> Enum.uniq(), else: nil

      Jason.encode!(%{
        law: law,
        amending: amending,
        effect: e.effect_id,
        type: e.type,
        affected: e.affected_provisions,
        affecting: e.affecting_provisions,
        refs: Enum.map(refs, &inspect/1),
        ids: ids
      })
    end

  File.write!(out, Enum.join(lines, "\n") <> "\n", [:append])
  if rem(i, 200) == 0, do: IO.puts("  #{i} amending laws")
end)
