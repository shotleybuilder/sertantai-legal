defmodule SertantaiLegal.Scraper.LawStart.Provisions.Rest do
  @moduledoc """
  The remaining provisions ("the rest of these Regulations", "all other provisions"), and the whole law staged by purpose. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.{Clause, ListItems, OwnDays, PurposeStages}
  alias SertantaiLegal.Scraper.LawStart.Provisions.{Refs, Treatment, Words}

  @cif Words.cif()
  @qualified Words.qualified()

  # a statement of the whole law: a general sentence, or the law's own list
  # item with the law for its subject ("This Order— … (c) comes into
  # force— (i) for the purposes of article 18(1), one month after the day
  # on which it is made; (ii) for all other purposes, on 5th October
  # 2015": SI 2015/776 art.1)
  @bare_open ~r/^\W*(?:\(\w+\)\s*)?(?:shall\s+)?(?:comes?|came)\s+into\s+(?:force|operation)\b/i

  @doc "Whether a statement is of the whole law (a general sentence, or the law's own list item)."
  @spec whole_law?(String.t()) :: boolean()
  def whole_law?(s), do: Clause.general?(s) or Regex.match?(@bare_open, s)

  # the whole law staged by purpose in one statement (`PurposeStages`): the
  # law is the subject, the provision only names the purpose, so the whole
  # law is partly in force on the first day and fully on the second ("…,
  # for the purpose of regulation 10(2), on 20th March 1991 and for all
  # other purposes on 1st September 1991": SI 1991/346 reg.1(1); Jason
  # 2026-11-20)
  @doc "The whole law staged by purpose in one statement: partly on the first day, fully on the second; nil when not so."
  @spec purpose_stages(String.t(), map(), [map()], OwnDays.days(), String.t()) :: [map()] | nil
  def purpose_stages(s, row, rows, made, base) do
    with [_subject, tail] <- Regex.split(@cif, s, parts: 2),
         [{:partial, purpose, _} | _] = stages <- PurposeStages.read(tail, made) do
      stages
      |> Enum.map(&stage_group(&1, row, s))
      |> PurposeStages.settle(fn _waiting -> Refs.weighted_refs(purpose, rows, base) end)
    else
      _ -> nil
    end
  end

  defp stage_group({:full, nil, date}, row, s), do: rest_group(:provision_dated, date, row, s)

  defp stage_group({:partial, _purpose, date}, row, s),
    do: rest_group(:provision_qualified, date, row, s)

  defp rest_group(treatment, date, row, text) do
    %{
      kind: :remaining,
      refs: [],
      excluded: [],
      treatment: treatment,
      date: if(treatment == :provision_qualified, do: nil, else: date),
      qualified_date: if(treatment == :provision_qualified, do: date),
      evidence: row.section_id,
      text: text
    }
  end

  # "except for regulation 4 and regulation 6 to the extent that it applies
  # to regulation 4, they shall come into force on 1st March 1994" (SI
  # 1994/232 reg.1(a)): the rest of the law less what is excepted outright;
  # an item excepted only to an extent comes in with the rest, partly
  @excepted_rest ~r/^\W*(?:\(\w+\)\s*)?(?:except(?:\s+for)?|other\s+than|apart\s+from)\s+(.+?),\s*(?:they|it|these\s+(?:Regulations|Rules)|this\s+(?:Order|Act|Measure))\s+(?:shall\s+)?comes?\s+into\s+(?:force|operation)\s+(.+?)$/is

  @doc "The rest of the law excepted from a statement (\"the remaining provisions …\"); nil when not so."
  @spec excepted_rest(String.t(), map(), [map()], OwnDays.days(), String.t()) :: [map()] | nil
  def excepted_rest(s, row, rows, made, base) do
    with [_, excepted, tail] <- Regex.run(@excepted_rest, String.trim(s)),
         {treatment, date} when treatment != :provision_unread <-
           Treatment.tail_treatment(tail, made) do
      {plain, _qualified} = ListItems.qualified_last(excepted) || {excepted, ""}

      [
        %{
          kind: :remaining,
          refs: [],
          excluded: Refs.refs(plain, rows, base),
          treatment: treatment,
          date: date,
          qualified_date: nil,
          evidence: row.section_id,
          text: s
        }
      ]
    else
      _ -> nil
    end
  end

  # … partly where it is qualified ("for the purpose of …", "in relation to
  # any container …"); a sentence dating each country apart ("in England on
  # 1st July 2007 and in Wales on 2nd April 2007": SI 2007/764) one partial
  # group per country, the country carried (`territory`)
  @by_country ~r/\bin\s+(England|Wales|Scotland|Northern Ireland)\s+on\s+(\d{1,2}\s*(?:st|nd|rd|th)?\s+[A-Za-z]+,?\s+\d{4})/i

  @doc "Another general sentence than the law's start: the rest of the law, dated."
  @spec general_rest(String.t(), map(), OwnDays.days()) :: [map()]
  def general_rest(s, row, made) do
    rest = fn t, d, text ->
      %{
        kind: :remaining,
        refs: [],
        excluded: [],
        treatment: t,
        date: if(t == :provision_qualified, do: nil, else: d),
        qualified_date: if(t == :provision_qualified, do: d),
        evidence: row.section_id,
        text: text
      }
    end

    case Regex.scan(@by_country, s) do
      [_, _ | _] = countries ->
        for [_, place, date] <- countries,
            %Date{} = d <- [Clause.date_at_start(date)],
            do: Map.put(rest.(:provision_qualified, d, s), :territory, place)

      _ ->
        dated_rest(s, made, rest)
    end
  end

  # the rest of the law on the sentence's own day (qualified where it is)
  defp dated_rest(s, made, rest) do
    with [_subject, tail] <- Regex.split(@cif, s, parts: 2),
         {t, d} when t in [:provision_dated, :provision_by_order] <-
           Treatment.tail_treatment(String.trim(tail), made) do
      t = if Regex.match?(@qualified, s), do: :provision_qualified, else: t
      [rest.(t, d, s)]
    else
      _ -> []
    end
  end
end
