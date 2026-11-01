defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmenderStart do
  @moduledoc """
  A change no source dates, by a law that came into force later than the
  provision it changes, never placed before that law existed (Jason
  2026-11-01, CV-06): dated at the earliest day its amending law came even
  partly into force — the earliest date that law's own commencement rules
  state (the Building Act 1984's Sch.7 repeals of HSWA ss.61–71: in force
  in part from 1 December 1984, the rest by an order not read). The last
  gap-filler, after `NoteDate`, never for a change marked prospective;
  the claim says so (`via:
  "amender_first_start"`), a derived date.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim}
  alias SertantaiLegal.Scraper.Commencement.Rule

  @dates [{:commencement, :date}, {:law_text, :date}, {:feed, :date}, {:feed, :date_first}]

  @doc "The date claims for `change` when nothing else dates it; [] otherwise."
  @spec claims(Change.t(), %{String.t() => [Rule.t()]}) :: [Claim.t()]
  def claims(%Change{} = c, commencement) do
    with true <- undated?(c),
         [law | _] <- amending_laws(c),
         %Date{} = d <- first_start(Map.get(commencement, law, [])) do
      Claim.new(:commencement, :date, d, c.key) ++
        Claim.new(:commencement, :via, "amender_first_start", c.key)
    else
      _ -> []
    end
  end

  @doc "The earliest day `rules` (a law's commencement rules) date; nil when none is dated."
  @spec first_start([Rule.t()]) :: Date.t() | nil
  def first_start(rules) do
    rules
    |> Enum.flat_map(fn
      %Rule{when: {:date, %Date{} = d}} -> [d]
      _ -> []
    end)
    |> Enum.min(Date, fn -> nil end)
  end

  # undated, and never one a source marks prospective: not in force yet
  # (Planning (Wales) Act 2026's repeal of TCPA 1990 s.78(4BA), golden)
  defp undated?(c),
    do:
      Enum.all?(@dates, fn {s, a} -> Change.values(c, s, a) in [[], [nil]] end) and
        true not in (Change.values(c, :feed, :prospective) ++
                       Change.values(c, :markup, :prospective))

  defp amending_laws(c) do
    (Change.values(c, :law_text, :by) ++
       Change.values(c, :feed, :by) ++ Change.values(c, :markup, :cited))
    |> Enum.filter(&is_binary/1)
    |> Enum.uniq()
  end
end
