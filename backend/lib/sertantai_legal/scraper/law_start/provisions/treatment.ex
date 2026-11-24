defmodule SertantaiLegal.Scraper.LawStart.Provisions.Treatment do
  @moduledoc """
  A group's treatment: from its tail (`:provision_dated`, `:provision_by_order`, `:provision_unread`) and its subject (`:provision_qualified`, the remaining provisions). Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.{Clause, OwnDays, Territorial}
  alias SertantaiLegal.Scraper.LawStart.Provisions.Words

  @qualified Words.qualified()

  @remaining ~r/\b(?:remaining (?:provisions|regulations|articles|sections|rules)|remainder|the rest of th(?:is|ese)|other provisions|all (?:other )?(?:provisions|regulations|articles|sections|rules)|provisions of this \w+(?: \([^)]*\))?,? except|preceding (?:provisions|Parts|sections|regulations|articles)|^\s*(?:\(\w+\)\s*)?otherwise\b|^\s*(?:\(\w+\)\s*)?(?:Subject to [^,]+,\s*)?the provisions of this)/i

  # a statement left to an order and qualified only by a country is by
  # order for that country, never a partial commencement ("in relation to
  # England, in accordance with provision made by order": CNEA 2005
  # s.108(1)(a))
  @doc "A group's treatment from its subject: qualified, remaining, unread or as dated."
  @spec classify(map(), String.t(), String.t()) :: map()
  def classify(g, qualifiable, subject \\ "") do
    case g.treatment == :provision_by_order && Territorial.only(qualifiable) do
      place when is_binary(place) ->
        by_order_for(g, place, Regex.match?(@remaining, subject))

      _ ->
        classify_plain(g, qualifiable, subject)
    end
  end

  # (the provisions it names stay named: "other provisions of Parts 1 and 2
  # come into force in relation to England in accordance with provision
  # made by order", FWMA 2010 s.49(3))
  defp by_order_for(%{refs: [_ | _]} = g, place, _rest?), do: Map.put(g, :territory, place)

  defp by_order_for(g, place, true), do: Map.merge(g, %{kind: :remaining, territory: place})

  defp by_order_for(g, _place, false), do: unread(g)

  defp unread(g), do: %{g | kind: :unread, treatment: :provision_unread, date: nil}

  # the rest of a container the statement names ("the remaining provisions
  # of Part 5", SSI 2020/154 reg.1(5); "The remainder of regulation 11",
  # NISR 2008/231 reg.1(5)) is that container's, never the whole law's: the
  # container stays named, and what another statement names within it keeps
  # its own day (the evaluator's most specific rule)
  @container_rest ~r/\b(?:(?:remaining|other)\s+provisions|remainder|rest)\s+of\s+(?:Parts?|Chapters?|regulations?|sections?|articles?|rules?)\s+(?:\d|[IVXL]+\b)/

  defp container_rest?(g, subject),
    do: g.refs != [] and g.treatment != :provision_unread and subject =~ @container_rest

  # provisions described, not named ("the provisions of this Order which
  # confer powers enabling rules or orders to be made … come into force on
  # the making of this Order, but for the purpose only of the exercise of
  # those powers": SI 2010/231 art.1(3)), are not read, whatever qualifies
  # the statement
  @described ~r/\bprovisions\s+of\s+(?:this|these)\s+\w+\s*,?\s+(?:which|that)\b/i

  defp described?(g, subject), do: g.refs == [] and subject =~ @described

  defp classify_plain(g, qualifiable, subject) do
    cond do
      Regex.match?(@qualified, qualifiable) ->
        if described?(g, subject),
          do: unread(g),
          else: %{g | treatment: :provision_qualified, date: nil, qualified_date: g.date}

      container_rest?(g, subject) ->
        g

      Regex.match?(@remaining, subject) and g.treatment != :provision_unread ->
        %{g | kind: :remaining}

      g.refs == [] or g.treatment == :provision_unread ->
        unread(g)

      true ->
        g
    end
  end

  @doc "A tail's treatment and date: `{:provision_dated, date}`, `{:provision_by_order, nil}` or `{:provision_unread, nil}`."
  @spec tail_treatment(String.t(), OwnDays.days()) ::
          {:provision_dated, Date.t()} | {:provision_by_order | :provision_unread, nil}
  def tail_treatment(tail, made) do
    # "in relation to Wales on 1st October 2020": the date after the place
    # (such a sentence is qualified: a partial rule, CR-03)
    tail =
      String.replace(
        tail,
        ~r/^(?:in relation to|in|as respects)\s+(?:England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland)\s+(?=on\b|from\b)/i,
        ""
      )

    # "… shall come into force for all purposes on 6th April 1992" (ICTA
    # 1988 s.843(3), SSCBA 1992 s.289(2): CV-S04)
    # ("for all remaining purposes, on 28th January 2013": SI 2012/2079
    # reg.1(3A)(b))
    tail =
      String.replace(
        tail,
        ~r/^for\s+all\s+(?:other\s+|remaining\s+)?purposes\s*,?\s+(?=on\b)/i,
        ""
      )

    # an item opening with its extent and closing with its day: "so far as
    # is necessary for the purpose of enabling the Secretary of State to
    # take action …, on 1st October 2012" (SI 2012/2079 reg.1(4)(a)); the
    # extent stays the statement's qualifier
    tail =
      String.replace(
        tail,
        ~r/^(?:in\s+)?so\s+far\s+as\s+(?:[^,()]|\((?:[^()]|\([^()]*\))*\)){1,400},\s+(?=on\s+\d{1,2}(?:st|nd|rd|th)?\s+[A-Z][a-z]+,?\s+\d{4}\W*$)/i,
        ""
      )

    # the day after the purpose: "comes into force, for the purposes of the
    # exercise of the power, on the day on which this Act is passed" (2011
    # c.19 s.38(1)); the purpose stays the statement's qualifier
    tail =
      String.replace(tail, ~r/^,\s*for\s+the\s+purposes?\s+of\s+[^,]{1,200},\s+(?=on\b)/i, "")

    case Clause.tail_date(tail, made) do
      {_, %Date{} = d} ->
        {:provision_dated, d}

      _ ->
        if Clause.by_order?(tail), do: {:provision_by_order, nil}, else: {:provision_unread, nil}
    end
  end

  # what an "except …" is relative to: the first provision named, else the
  # clause's own (a Part's, Chapter's or Schedule's id isn't a provision:
  # "Part 7 …, except regulation 73"; "Chapter 1 of Part 5 (except section
  # 116), Part 5 of Schedule 18": 2007 c.28 s.245(2))
  @doc "What an \"except …\" is relative to: the first provision named, else `base`."
  @spec relative_base([{String.t(), term()}], String.t()) :: String.t()
  def relative_base(named, base) do
    case named
         |> Enum.map(&elem(&1, 0))
         |> Enum.reject(&String.contains?(&1, [":pt.", ":sch"])) do
      [first | _] -> first
      [] -> base
    end
  end
end
