defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Bench do
  @moduledoc """
  The census's recall bench (CV-S05d `bench.py`, #192): each agent NEW of
  rounds 9–12 on the law's stored reading, the live one where the defect
  is still open, else the reading with the faulty rows the agent
  recorded put back (the CV-S05 session's round notes). The census must
  flag each; `bench.txt` says which it did.
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus
  alias SertantaiLegal.Scraper.Checks.ExtentCensus.{LawCheck, Structure}

  @doc "The cases: {name, law, mutation of the dump line or nil, expected [{sentence ref, verdict} | {\"unnamed\", ref}]}."
  @spec cases() :: [{String.t(), String.t(), (map() -> map()) | nil, [{String.t(), String.t()}]}]
  def cases do
    [
      {"r9 NEW-1 default E+W+NI", "UK_ukpga_2002_30", &Map.put(&1, "default", "E+W+NI"),
       [{"s.108", "whole_mismatch"}]},
      {"r10 NEW-1 Sch.13 applies dropped", "UK_uksi_2014_1638", &Map.put(&1, "applies", []),
       [{"reg.3", "place"}]},
      {"r10 NEW-2 other-than read as items", "UK_ukpga_2009_23",
       &add(&1, "also", "S", ["s.146", "sch.8.para.1", "sch.11"]), [{"s.323", "exc_held"}]},
      {"r10 NEW-2 'in Chapter 1 of Part 6' read whole", "UK_ukpga_2009_23",
       &add(&1, "also", "S", ["s.150", "s.151"]), [{"unnamed", "s.150"}]},
      {"r10 NEW-2 Chapters 1 to 5 of Part 8 (live)", "UK_ukpga_2009_23", nil,
       [{"unnamed", "s.293"}]},
      {"r10 NEW-3 'this Chapter' dropped (live)", "UK_ukpga_2017_3", nil, [{"s.182", "missing"}]},
      {"r11 NEW-1 1977/45 s.65(10) items dropped", "UK_ukpga_1977_45",
       &Map.update!(&1, "lists", fn ls -> Enum.reject(ls, fn r -> r["kind"] == "unread" end) end),
       [{"s.65", "q_missing"}]},
      {"r12 NEW-1 locator read whole (live)", "UK_uksi_2020_818", nil, [{"reg.1A", "broader"}]},
      {"r12 NEW-2 'They apply …' in noise (live)", "UK_uksi_2016_1154", nil,
       [{"reg.1", "whole_missing"}]},
      {"r12 NEW-3 '34 (f)' read whole (live)", "UK_uksi_2013_1506", nil, [{"reg.3", "broader"}]}
    ]
  end

  @doc "The laws the bench reads."
  @spec laws() :: [String.t()]
  def laws, do: cases() |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

  @doc "`bench.txt` for the dump lines `by_law` (a map of law to its line), structures as `ExtentCensus.run/2` takes them."
  @spec run(%{String.t() => map()}, :store | %{String.t() => Structure.t()}) :: String.t()
  def run(by_law, structures) do
    lines =
      for {name, law, mutate, expect} <- cases() do
        d = if mutate, do: mutate.(by_law[law]), else: by_law[law]

        {found, unnamed} =
          LawCheck.check(d, ExtentCensus.frozen(structures, law) || Structure.read(law))

        {Enum.all?(expect, &hit?(&1, found, unnamed)), name}
      end

    ok = Enum.count(lines, &elem(&1, 0))

    Enum.map_join(lines, fn {hit, name} ->
      if(hit, do: "FLAGGED ", else: "MISSED  ") <> name <> "\n"
    end) <>
      "#{ok}/#{length(lines)} flagged\n"
  end

  defp hit?({"unnamed", ref}, _found, unnamed), do: Enum.any?(unnamed, &(elem(&1, 2) == ref))

  defp hit?({ref, verdict}, found, _unnamed),
    do:
      Enum.any?(found, fn f ->
        f.ref == ref and Enum.any?(f.verdicts, &(elem(&1, 0) == verdict))
      end)

  # a list row's refs added to (the first of that kind and place), else a new row
  defp add(d, kind, place, refs) do
    lists = d["lists"]

    lists =
      case Enum.find_index(lists, &(&1["kind"] == kind and &1["place"] == place)) do
        nil -> lists ++ [%{"kind" => kind, "place" => place, "refs" => refs}]
        i -> List.update_at(lists, i, &Map.update!(&1, "refs", fn rs -> rs ++ refs end))
      end

    %{d | "lists" => lists}
  end
end
