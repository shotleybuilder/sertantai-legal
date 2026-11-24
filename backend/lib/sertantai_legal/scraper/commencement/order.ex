defmodule SertantaiLegal.Scraper.Commencement.Order do
  @moduledoc """
  A commencement order as rules (commencement-rules CR-04): what the order
  brings into force of the law it commences, when, where and how far.

  Statements read (an article or paragraph whose own words carry them):

  - "<items> come(s) into force on <date>" — the items inline ("Sections 17
    to 22 of, and Schedule 4 to, the Act …") or listed below ("The following
    provisions … come into force on 1st October 2006— section 1(4); …");
  - "<date> is the day appointed for the coming into force of <items>";
  - a Schedule table of provisions and purposes, dated by its title or by
    the article that brings it in;
  - the whole Act: "The Employment Medical Advisory Service Act 1972 shall
    come into operation on 1st February 1973" (SI 1973/28), "Apart from the
    provisions mentioned in paragraph (2), the … Act 2007 shall, to the
    extent that it is not already in force, come into force on 6th April
    2008" (SI 2008/401: all but the paragraph's provisions; CV-S04).

  Items: sections (lists, ranges, subsections: "in section 61, subsection
  (6)"), Schedules, "paragraphs … of Schedule N" (or under "the following
  paragraphs of Schedule N—", or "in Schedule N to the Act, paragraphs …").
  "Section 120(1) in so far as it relates to the following paragraphs of
  Schedule 22" brings those paragraphs in fully and the section partly. "So
  far as not already in force" / "for all (remaining) purposes" / "(except
  so far as already in operation)" / "(except as aforesaid)" (SI 1974/1439:
  the rest of a provision an earlier entry brought in partly) is full; any
  other "so far as" / "for the purposes of" / "except" is partial (the four
  purposes); "in relation to Wales" is the territory. Another law's
  provisions ("section 70 of the Transport Act 1962") are never the Act's.

  Refs in the commenced law's grammar: "s.17..s.22", "s.36(3)", "sch.4",
  "sch.10.para.3..sch.10.para.6", "sch.21.para.2(1)". `ref/1` turns an
  amending provision's CLML id into one; `context/0` gives the evaluator
  the Schedule a paragraph belongs to. Pure: the order and the Act's
  identity come in.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  alias SertantaiLegal.Scraper.Commencement.Order.{
    AppointedFor,
    Identity,
    ScheduleLists,
    ScheduleTables,
    Statements,
    Territory,
    WholeAct
  }

  alias SertantaiLegal.Scraper.Commencement.{Authority, ClmlRef, RefContext, Rule, TextRefs}

  @type act :: %{
          required(:law) => String.t(),
          required(:title) => String.t() | nil,
          required(:year) => String.t(),
          optional(:authorities) => Authority.t()
        }
  @doc "The rules an order states for the law `act` it commences ([] when it doesn't commence it)."
  @spec rules(Doc.t(), act()) :: [Rule.t()]
  def rules(%Doc{} = order, act) do
    # an order never commences itself (NISR 2012/286, read as its own Act's
    # orders when it was the law asked about: CV-S04)
    if order.law_name != act.law and Identity.commences?(order, act) do
      aliases = Identity.aliases(order, act)

      type_territory = order_territory(order, act)

      (Statements.statements(order, aliases) ++
         WholeAct.whole_act(order, aliases) ++
         AppointedFor.appointed_for(order, aliases) ++
         ScheduleTables.tables(order, act) ++ ScheduleLists.schedule_lists(order, aliases))
      |> Enum.flat_map(&own_articles(&1, act))
      |> Enum.flat_map(&placed(%{&1 | commences: act.law}, order, act, type_territory))
    else
      []
    end
  end

  # the order's own place: none for a devolved order on its own
  # legislature's Act, whose extent gives it — never its title's or its
  # application's ("This Order applies in relation to Wales": WSI 2011/476
  # on the Waste (Wales) Measure 2010); else its type's, title's or
  # application's
  defp order_territory(order, act) do
    if Territory.own_legislature?(order.law_name, act.law),
      do: nil,
      else:
        Territory.of_type(order.law_name, act.law) ||
          Territory.of_title(Identity.full_title(order)) ||
          applies_to(order)
  end

  # a rule's place: its own words', else its authority's or the order's
  defp placed(rule, order, act, type_territory) do
    case rule.territory || Territory.head_territory(rule) do
      nil -> by_authority(order, act, rule, type_territory)
      place -> [%{rule | territory: place}]
    end
  end

  # where the Act's commencing authority that made the order may bring the
  # rule's provisions in, else the order's own type, title or application
  # (Decision 10: Water Act 2003 s.105(6) — a UK order's s.77 is England's,
  # a Welsh order's s.67 everywhere's; "sections 81 to 83" split at s.81)
  defp by_authority(order, act, rule, otherwise) do
    act
    |> Map.get(:authorities, [])
    |> Authority.split(rule.scope, maker(order.law_name))
    |> Enum.map(fn
      {scope, except, :default} ->
        %{rule | scope: scope, except: rule.except ++ except, territory: otherwise}

      {scope, [], place} ->
        %{rule | scope: scope, territory: place}
    end)
  end

  defp maker("UK_uksi_" <> _), do: :uk
  defp maker("UK_wsi_" <> _), do: :wales
  defp maker("UK_ssi_" <> _), do: :scotland
  defp maker(_order), do: nil

  # "This Order applies in relation to England only." (SI 2010/975
  # art.1(2)): the first article's paragraph naming the one place
  defp applies_to(order) do
    Enum.find_value(order.ids, fn id ->
      if id =~ ~r/^(?:article|regulation)-1(?:-\d+)?$/,
        do:
          order |> Doc.element(id) |> Doc.lines() |> Enum.find_value(&Territory.of_application/1)
    end)
  end

  # the law types whose provisions are Articles or regulations (an Order in
  # Council: NISI 1992/1728); an Act's are sections
  @instruments ~w(nisi uksi ssi wsi nisr uksro nisro ukmo ukci)

  # an Article named in an order is the commenced law's only where that law
  # is an instrument; for an Act it is the order's own ("Article 3 comes
  # into force on 1st April 2015": SSI 2015/139), never a provision of the Act
  defp own_articles(%Rule{scope: scope} = rule, act) when is_list(scope) do
    if (act.law |> String.split("_") |> Enum.at(1)) in @instruments do
      [rule]
    else
      case Enum.reject(scope, &String.starts_with?(&1, "reg.")) do
        [] -> []
        kept -> [%{rule | scope: kept}]
      end
    end
  end

  defp own_articles(rule, _act), do: [rule]

  @doc "The Schedule provisions a law's own clause `text` names (`TextRefs.own_schedule_refs/1`)."
  @spec own_schedule_refs(String.t()) :: [String.t()]
  defdelegate own_schedule_refs(text), to: TextRefs

  @doc "An amending provision's CLML id as a ref: \"section-36-3\" → \"s.36(3)\", \"schedule-11-paragraph-137-a\" → \"sch.11.para.137(a)\"."
  @spec ref(String.t()) :: String.t() | nil
  defdelegate ref(id), to: ClmlRef

  @doc "The evaluator's context for an amending law's refs (`RefContext.context/0`)."
  @spec context() :: map()
  defdelegate context(), to: RefContext

  @doc "The Act's provisions an order's `text` names, as this reader names them (`TextRefs.refs_in/1`): for checks (`Commencement.Leftovers`)."
  @spec refs_in(String.t()) :: [String.t()]
  defdelegate refs_in(text), to: TextRefs

  @doc "The law's title from its own CLML (`dc:title`), without the year: for an Act `uk_lrt` doesn't hold (`Order.Identity`)."
  @spec title(Doc.t()) :: String.t() | nil
  defdelegate title(doc), to: Identity

  @doc "True when the order commences `act` (`Order.Identity`)."
  @spec commences?(Doc.t(), act()) :: boolean()
  defdelegate commences?(order, act), to: Identity

  @doc "Rules left to the day an Act's own provision appoints, resolved against the Act's rules (`Order.AppointedFor`)."
  @spec resolve_appointed_for([Rule.t()], [Rule.t()]) :: [Rule.t()]
  defdelegate resolve_appointed_for(rules, act_rules), to: AppointedFor
end
