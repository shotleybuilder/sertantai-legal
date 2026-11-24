defmodule SertantaiLegal.Scraper.LawStart.Provisions.Countries do
  @moduledoc """
  A commencement country by country ("in its application to England and Wales … and in its application to Scotland …"), or later for one purpose. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.{OwnDays, Territorial}
  alias SertantaiLegal.Scraper.LawStart.Provisions.{Refs, Treatment}

  # "Part II of this Act, in its application to England and Wales, shall
  # come into operation on such day as …, and in its application to
  # Scotland on such day as …" (1969 c.10 s.38(3)): the subject's
  # provisions, one group per country with its own day
  @doc "A subject commenced country by country: one group per country with its own day; nil when not so."
  @spec by_application(String.t(), map(), [map()], OwnDays.days(), String.t()) :: [map()] | nil
  def by_application(s, row, rows, made, base) do
    with {subject, countries} <- Territorial.by_application(s),
         [_ | _] = refs <- Refs.weighted_refs(subject, rows, base) do
      for {place, tail} <- countries,
          do: country_group(Treatment.tail_treatment(tail, made), place, refs, row, s)
    else
      _ -> nil
    end
  end

  defp country_group({treatment, date}, place, refs, row, s) do
    dated? = treatment == :provision_dated

    %{
      kind: :named,
      refs: refs,
      excluded: [],
      treatment: if(dated?, do: :provision_qualified, else: treatment),
      date: nil,
      qualified_date: if(dated?, do: date),
      territory: place,
      evidence: row.section_id,
      text: s
    }
  end

  # "… shall come into force on 23rd February 2008, except that— (a) in
  # relation to noise arising from …, these Regulations shall come into
  # force on 6th April 2008" (SI 2007/3075 reg.1(a)): the law later for some
  # purposes — as "not until": in partly from its start, fully from that
  # date. (A place is a territory's own date, never this: `@by_country`.)
  @later_for ~r/^\W*(?:\(\w+\)\s*)?(?:in\s+relation\s+to|for\s+the\s+purposes?\s+of|in\s+the\s+case\s+of|as\s+respects)\s+([^,]+),\s*(?:these\s+(?:Regulations|Rules)|this\s+(?:Order|Act|Measure)|they|it)\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\s+(.+?)$/is

  @place ~r/^(?:England|Wales|Scotland|Northern Ireland|Great Britain|England and Wales)$/i

  @doc "The law later for one purpose: partly from its start, fully from that day; nil when not so."
  @spec later_for(String.t(), map(), OwnDays.days(), Date.t() | nil) :: [map()] | nil
  def later_for(s, row, made, %Date{} = start) do
    with [_, purpose, tail] <- Regex.run(@later_for, String.trim(s)),
         false <- Regex.match?(@place, String.trim(purpose)),
         tail = String.replace(tail, ~r/[\s;,.]*(?:and|or)?\s*$/i, ""),
         {:provision_dated, %Date{} = d} <- Treatment.tail_treatment(tail, made),
         :gt <- Date.compare(d, start) do
      g = %{kind: :remaining, refs: [], excluded: [], evidence: row.section_id, text: s}

      [
        Map.merge(g, %{treatment: :provision_qualified, date: nil, qualified_date: start}),
        Map.merge(g, %{treatment: :provision_dated, date: d, qualified_date: nil})
      ]
    else
      _ -> nil
    end
  end

  def later_for(_s, _row, _made, _start), do: nil
end
