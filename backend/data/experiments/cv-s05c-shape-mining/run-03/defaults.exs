# usage (from backend/): mix run DIR/defaults.exs DIR/sentences.tsv DIR/defaults.tsv
# CV-S05c census, added in run-03 (CV-S05 round 12, after the seed 16 NEW-1):
# a sentence credited as the law's default that carries lettered items stating
# their own extent ("In this Act— (a) … extend to Scotland; … but save as
# aforesaid, this Act extends to England and Wales only"). Each such item's
# provisions (`Credit.own_refs/3`) must be in some list the reader holds (any
# kind, unread included); one in none is a silent drop.
[src, out] = System.argv()

alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Credit, ReadCache, Units}
alias SertantaiLegal.Scraper.LegislationGovUk.ClmlStore

rows =
  src
  |> File.stream!()
  |> Stream.drop(1)
  |> Enum.map(&(&1 |> String.trim_trailing("\n") |> String.split("\t")))
  |> Enum.filter(fn [_, _, class, s] ->
    String.starts_with?(class, "default") and s =~ ~r/[—–]/u
  end)

lines =
  rows
  |> Enum.group_by(&hd/1)
  |> Task.async_stream(
    fn {law, sents} ->
      doc =
        Doc.new(law, Enum.map(ClmlStore.law_files(law), &(&1 |> File.read!() |> :zlib.gunzip())))

      e = ReadCache.law(law, doc: doc).read
      held = for {_, _, refs} <- e.lists, r <- refs, do: r

      for [_, ref, class, s] <- sents,
          item <- s |> Units.statements() |> tl(),
          item =~ ~r/\b(?:extends?|extend|same\s+extent)\b/u,
          own = Credit.own_refs(item, ref, doc),
          is_list(own) and own != [],
          missing =
            Enum.reject(own, fn r ->
              "*" in held or Enum.any?(held, &(&1 == r or RefList.covers?(&1, r)))
            end),
          missing != [] do
        Enum.join([law, ref, class, Enum.join(missing, " "), String.slice(item, 0, 200)], "\t")
      end
    end,
    max_concurrency: 2,
    timeout: :infinity
  )
  |> Enum.flat_map(fn {:ok, l} -> l end)

File.write!(out, "law\tref\tclass\tmissing\titem\n" <> Enum.join(Enum.sort(lines), "\n") <> "\n")

IO.puts(
  "#{length(rows)} default sentences with a dash; #{length(lines)} items with provisions in no list"
)
