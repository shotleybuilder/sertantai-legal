# usage (from backend/): mix run DIR/dump.exs DIR/sentences.tsv
# every held law's extent sentences, in full, with the reader's class (CV-S05c)
[out] = System.argv()
alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache
laws = ReadCache.held()

lines =
  laws
  |> Task.async_stream(
    fn law ->
      case ReadCache.law(law) do
        nil ->
          []

        r ->
          for {ref, s, c} <- r.classes,
              do: Enum.join([law, ref, c, String.replace(s, ~r/\s+/u, " ")], "\t")
      end
    end,
    max_concurrency: 4,
    timeout: :infinity
  )
  |> Enum.flat_map(fn {:ok, l} -> l end)

File.write!(out, "law\tref\tclass\tsentence\n" <> Enum.join(Enum.sort(lines), "\n") <> "\n")
IO.puts("#{length(laws)} laws, #{length(lines)} sentences")
