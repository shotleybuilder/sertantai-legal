# usage (from backend/): mix run DIR/dump.exs OUT.jsonl [LAW ...]
# every held law's stored extent reading (default, lists, applies,
# application), its catalogue sentences and the sweep's uncaught sentences
# with their sweep form, as JSON lines (CV-S05d). Read-only (ReadCache).
alias SertantaiLegal.Scraper.AmendingLaw.Extent.ReadCache
alias SertantaiLegal.Scraper.AmendingLaw.SweepForm
[out | only] = System.argv()
laws = if only == [], do: ReadCache.held(), else: only

rows = fn l -> for {k, p, refs} <- l, do: %{kind: k, place: p, refs: refs} end

lines =
  laws
  |> Task.async_stream(
    fn law ->
      case ReadCache.law(law) do
        nil ->
          nil

        r ->
          Jason.encode!(%{
            law: law,
            default: r.read.default,
            application: r.read.application,
            lists: rows.(r.read.lists),
            applies: rows.(r.read.applies),
            sentences:
              for({ref, s, c} <- r.classes, do: %{ref: ref, class: c, s: s}) ++
                for(
                  {ref, s, net} <- r.uncaught,
                  do: %{ref: ref, class: "sweep:" <> SweepForm.form(s), net: net, s: s}
                )
          })
      end
    end,
    max_concurrency: 4,
    timeout: :infinity
  )
  |> Enum.flat_map(fn
    {:ok, nil} -> []
    {:ok, l} -> [l]
  end)

File.write!(out, Enum.join(lines, "\n") <> "\n")
IO.puts("#{length(laws)} laws, #{length(lines)} read")
