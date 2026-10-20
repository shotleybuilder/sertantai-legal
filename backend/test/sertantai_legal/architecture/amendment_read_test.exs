defmodule SertantaiLegal.Architecture.AmendmentReadTest do
  @moduledoc """
  One amendment path (amendment-rules AR-04): an amending law's
  instructions are read only by the ruleset's reader (`Amendment.Reader`,
  into `amendment_rules`), and the change register's amending-law records
  are made only by its collector (`Amendment.Collect`, which asks the
  evaluator). A new row matcher — a module asking `Operation` for a verb,
  or making `law_pointer` records — fails this test; read it as a rule
  instead.
  """
  use ExUnit.Case, async: true

  @lib Path.expand("../../../lib", __DIR__)

  defp offenders(pattern, allowed) do
    for path <- Path.wildcard(Path.join(@lib, "**/*.ex")),
        rel = Path.relative_to(path, @lib),
        rel not in allowed,
        File.read!(path) =~ pattern,
        do: rel
  end

  test "only the reader asks an instruction's operation" do
    assert offenders(~r/\bOperation\.of(?:_quoted)?\(/, [
             "sertantai_legal/scraper/amendment/reader.ex"
           ]) == []
  end

  test "only the ruleset collector makes amending-law records" do
    assert offenders(~r/"law_pointer"/, ["sertantai_legal/scraper/amendment/collect.ex"]) == []
  end
end
