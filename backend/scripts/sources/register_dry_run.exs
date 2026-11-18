# Sources: the register-differences dry run (WORKFLOW, Sources, "Register differences").
#
#   mix run scripts/sources/register_dry_run.exs <gate report> <out file> [--apply]
#
# --apply (after Jason's go and a restore point of legal_register) writes each
# law through LawParser.persist_direct, as the scrape page does, and prints
# live and statistics before -> after with the columns that moved.
#
# Reads each "UK_…: effects F vs register R; laws f vs r" line of a
# `mix lat.sources --all` report and re-reads that law's change statistics
# through the register's own stage (StagedParser :amended_by). No database
# write; the stage does refresh the law's stored feed, so rebuild any law whose
# feed moves. One line per law: stored, feed, fresh, the stage's status, and
# live status before -> after (the re-scrape runs LiveStatus), with its
# description and evidence.
alias SertantaiLegal.Repo
alias SertantaiLegal.Scraper.{LawParser, ParsedLaw, StagedParser}
[report, out | flags] = System.argv()
apply? = "--apply" in flags

row = fn law ->
  Repo.query!("SELECT row_to_json(u)::jsonb FROM uk_lrt u WHERE name=$1", [law]).rows
  |> List.flatten()
  |> List.first() || %{}
end

moved = fn a, b -> for {k, v} <- b, a[k] != v, do: k end

rows =
  for l <- File.stream!(report),
      m = Regex.run(~r/^  (UK_\S+): effects (\d+) vs register (\d+); laws (\d+) vs (\d+)/, l),
      m != nil,
      do: m

File.write!(out, "")

for [_, law, fe, re, fl, rl] <- rows do
  [_, t, y, n] = String.split(law, "_", parts: 4)

  live =
    Repo.query!("SELECT live FROM uk_lrt WHERE name=$1", [law]).rows
    |> List.flatten()
    |> List.first()

  {:ok, r} = StagedParser.parse(%{type_code: t, Year: y, Number: n}, stages: [:amended_by])
  p = r.law
  st = r.stages[:amended_by][:status]

  line =
    Enum.join(
      [
        law,
        "stored #{re}/#{rl}",
        "feed #{fe}/#{fl}",
        "fresh #{p.amended_by_stats_affected_by_count}/#{p.amended_by_stats_affected_by_laws_count}",
        "stage #{st}",
        "live #{live} -> #{p.live}",
        "why #{p.live_description}",
        "evidence #{Jason.encode!(p.live_evidence)}"
      ],
      " | "
    )

  line =
    if apply? and st == :ok do
      before = row.(law)
      res = LawParser.persist_direct(ParsedLaw.to_comparison_map(p))
      aft = row.(law)

      "#{if match?({:ok, _}, res), do: "APPLIED", else: "FAILED #{inspect(res)}"} " <>
        "#{law}: live #{before["live"]} -> #{aft["live"]}; " <>
        "stats #{before["🔻_stats_affected_by_count"]} -> #{aft["🔻_stats_affected_by_count"]}; " <>
        "moved #{inspect(Enum.sort(moved.(before, aft)))}"
    else
      line
    end

  File.write!(out, line <> "\n", [:append])
end
