defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffecting do
  @moduledoc """
  The amending provisions a changes-feed effect names (its
  `affecting_provisions` text) as refs, named as our provisions are named
  (`Commencement.Order.ref`): "s. 29(4)" → "s.29(4)", "Sch. 7 para. 27(2)"
  → "sch.7.para.27(2)", and an article "art. 18" → "reg.18" (an Order's
  articles are `reg.` rows; CV-S05 round 7 NEW-6: SI 2022/1174 art. 18 was
  never found in its extent list). A range ("regs 11-14") is every
  provision from its start to its end; a list ("arts. 2 3", "art. 3-6
  8-10") is every provision listed. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffectingSiblings, as: Siblings
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffectingSpan, as: Span

  # (an unnumbered Schedule's paragraph, "Sch. para. 3(1)(b)": CV-S07 round 3;
  # a range, "regs 11-14", "art. 11(1)-(3)", "Sch. 2 para. 3-5", with the
  # kind named in the plural: Fire and OH&S, Feed reader; a list, "arts. 2
  # 3", "regs 2, 3", and a bare continuation, "art. 3-6 8-10", "s. 10(2)(a)
  # (4)": Waste, Water and Climate, Feed reader)
  @number ~S"\d+[A-Z]*(?:\([^)]+\))*"
  @upto ~S"(?:\([^)]+\))+"
  @bare ~S"(?:\([A-Za-z0-9]+\))+"

  # the text in its pieces, each one of: a gap, a Schedule, a Part with its
  # number, a paragraph, a kind (in the plural or with no full stop only
  # before a number), a number or range, a bare bracketed number or range,
  # anything else (another law's number "1997/2965" is no provision's)
  @pieces Regex.compile!(
            ~S"(?<gap>[\s,]+)" <>
              ~S"|(?<sch>\bSch(?:\.|s\.?(?=\s*\d)))" <>
              ~S"|\bPt\.\s*(?<pt>\d+[A-Z]*|[IVXLC]+)" <>
              ~S"|(?<para>\bparas?\.|\bparas(?=\s*\d))" <>
              ~S"|(?<kind>\b(?:s|reg|art)(?=\.)|\b(?:ss|regs|arts)(?=\.?\s*\d)|\b(?:reg|art)(?=\s*\d))\.?" <>
              "|(?<n>#{@number})(?![\\d/])(?:\\s*-\\s*(?<n_to>#{@number}|#{@upto}))?" <>
              "|(?<sub>#{@bare})(?:\\s*-\\s*(?<sub_to>#{@upto}))?" <>
              ~S"|(?<other>\w+|.)",
            "su"
          )

  # a bracket saying what the affecting provision does to another law:
  # "(adding 1949 c. 30 s. 3A(1)-(3))", "(addingto1986 c 53 Sch. 15A)",
  # "(substituting 1968 c 47 s. 10)", "(subst.1995/1544 reg. 10(2))",
  # "(amending1973 c 65 s. 92(2))", "(am.1976 c 76 s 9(1))", "(replacing
  # 1988 c. 1 s.749 at s.749A(4)(a))", "(modifying1984 c 47 Sch. para. 2)".
  # The provisions it names are the other law's, never the affecting law's
  # own (Fire and OH&S, and Waste, Water and Climate: Feed reader). The
  # words are every one the stored feeds open such a bracket with, the
  # feed's misspellings included ("subsituting", "substutiting"); a
  # bracketed sub-number of our own ("(4)", "(am)", "(aaa)") opens with
  # none of them. The tail runs to the end, unbalanced
  @tail_words ~S"adding|subst\.|subs[a-z]*ting|amending|am\.|as\s+am\.|replacing|modifying" <>
                ~S"|inserting|insertedby|extending|reprinting|and\s+see|s\.[^()]*addedto"
  @tail Regex.compile!(~S"\(\s*(?:" <> @tail_words <> ").*$", "isu")

  # where the reading stands: the prefix the next number takes (nil: none),
  # the level it names (a Schedule, a Part, or a provision), the Schedule it
  # is under (nil: none; "": unnumbered), the last provision's number (a
  # bare bracketed number continues it), and the refs a paragraph or Part
  # that follows stands in place of (`held`: "Sch. 7 para. 3" is the
  # paragraph, never the Schedule)
  @start %{prefix: nil, level: :provision, sch: nil, last: nil, held: 0, into: false, refs: []}

  @doc ~S"""
  Every provision named: "Sch. 7 para. 27(2) Sch. 17 Pt. 2" →
  ["sch.7.para.27(2)", "sch.17.pt.2"]; "s. 111, Sch. 7" → ["s.111", "sch.7"].

  A range names every provision from its start to its end, by number or
  letter: "regs 11-14" → ["reg.11", "reg.12", "reg.13", "reg.14"];
  "art. 11(1)-(3)" → ["reg.11(1)", "reg.11(2)", "reg.11(3)"]. Ends that
  cannot be counted between (lettered numbers "2A-2D", roman numerals,
  ends at different depths) give the two ends.

  A list names every provision listed, a bare number or range continuing
  the kind before it: "arts. 2 3 Sch. 1" → ["reg.2", "reg.3", "sch.1"];
  "art. 3-6 8-10" → reg.3 to reg.6 and reg.8 to reg.10; "Sch. 6 paras.
  2(4) 7" → ["sch.6.para.2(4)", "sch.6.para.7"]. A bare bracketed number
  stands in place of the last number's part of its own kind: "s. 10(2)(a)
  (4)" → ["s.10(2)(a)", "s.10(4)"]; "s. 104(5)(a) (b)" → ["s.104(5)(a)",
  "s.104(5)(b)"]. Bracketed numbers written together are siblings where
  one follows another of its own form (`FeedAffectingSiblings`): "s.
  52(8)(9)" → ["s.52(8)", "s.52(9)"]; "s. 1(1)(a)" is the one provision.

  A closing bracket saying what the provision does to another law is not
  read: "s. 74(4) 102(substituting 1968 c 47 s. 10)" → ["s.74(4)",
  "s.102"].
  """
  @spec refs(String.t() | nil) :: [String.t()]
  def refs(nil), do: []

  def refs(text) do
    @pieces
    |> Regex.scan(String.replace(text, @tail, ""), capture: :all_names)
    |> Enum.reduce(@start, &piece/2)
    |> Map.fetch!(:refs)
    |> Enum.reverse()
  end

  # the captures by name, in name order: gap, kind, n, n_to, other, para,
  # pt, sch, sub, sub_to
  defp piece([gap, "", "", "", "", "", "", "", "", ""], at) when gap != "", do: at
  defp piece([_, kind, "", _, _, _, _, _, _, _], at) when kind != "", do: kind(at, kind)
  defp piece([_, _, n, to, _, _, _, _, _, _], at) when n != "", do: number(at, n, to)
  defp piece([_, _, _, _, _, para, _, _, _, _], at) when para != "", do: paragraph(at)
  defp piece([_, _, _, _, _, _, pt, _, _, _], at) when pt != "", do: part(at, pt)
  defp piece([_, _, _, _, _, _, _, sch, _, _], at) when sch != "", do: schedule(at)
  defp piece([_, _, _, _, _, _, _, _, sub, to], at) when sub != "", do: bare(at, sub, to)
  defp piece(_other, at), do: stop(at)

  defp stop(at), do: %{@start | refs: at.refs}

  defp kind(at, kind), do: %{stop(at) | prefix: "#{prefix(kind)}."}

  defp schedule(at), do: %{stop(at) | prefix: "sch.", level: :schedule, sch: ""}

  # a paragraph or a Part is read only under a Schedule
  defp paragraph(%{sch: nil} = at), do: stop(at)

  defp paragraph(%{sch: sch} = at),
    do: %{at | prefix: under(sch) <> "para.", level: :provision, last: nil, into: true}

  defp part(%{sch: nil} = at, _pt), do: stop(at)
  defp part(%{sch: ""} = at, _pt), do: %{at | prefix: nil, level: :part, last: nil}

  # a Schedule's first Part stands in place of the Schedule held
  defp part(%{sch: sch, level: level} = at, pt) do
    prefix = under(sch) <> "pt."
    at = if level == :schedule, do: unhold(at), else: at
    hold(%{at | prefix: prefix, level: :part, last: nil}, [prefix <> pt])
  end

  defp under(""), do: "sch."
  defp under(sch), do: "sch.#{sch}."

  # a number with no kind before it is no provision's ("Note 1", "Table 9")
  defp number(%{prefix: nil} = at, _n, _to), do: at

  defp number(%{level: :schedule} = at, n, to) do
    sch = whole(n)
    hold(%{at | sch: sch}, Span.refs("sch.", sch, whole(to)))
  end

  defp number(%{level: :part, prefix: prefix} = at, n, to),
    do: hold(at, Span.refs(prefix, whole(n), whole(to)))

  defp number(at, n, to), do: several(at, Siblings.split(n), to)

  # "(4)" after "s. 10(2)(a)": s.10(4)
  defp bare(%{last: nil} = at, _sub, _to), do: at
  defp bare(%{last: last} = at, sub, to), do: several(at, Siblings.continued(last, sub), to)

  # numbers written together, each a provision ("52(8)(9)": s.52(8) and
  # s.52(9)); a range ends the last
  defp several(%{prefix: prefix} = at, numbers, to) do
    {before, [last]} = Enum.split(numbers, -1)
    add(%{at | last: last}, Enum.map(before, &(prefix <> &1)) ++ Span.refs(prefix, last, to))
  end

  # the refs a paragraph or Part that follows stands in place of
  defp hold(at, refs), do: %{at | refs: Enum.reverse(refs, at.refs), held: length(refs)}

  defp unhold(at), do: %{at | refs: Enum.drop(at.refs, at.held), held: 0}

  # a Schedule's first paragraph stands in place of the Schedule or Part held
  defp add(%{into: true} = at, refs), do: add(unhold(%{at | into: false}), refs)
  defp add(at, refs), do: %{at | refs: Enum.reverse(refs, at.refs), held: 0}

  # a Schedule's or Part's number without its brackets: "19(1)" → "19"
  defp whole(n), do: ~r/^\d+[A-Z]*/ |> Regex.run(n) |> List.wrap() |> List.first("")

  @doc ~S"""
  The one provision named ("s. 47(1)" → "s.47(1)"; "Sch. 5 para. 3" →
  "sch.5.para.3"), nil for any other form.
  """
  @spec ref(String.t() | nil) :: String.t() | nil
  def ref(nil), do: nil

  def ref(text) do
    cond do
      m = Regex.run(~r/^\s*(s|reg|art)\.\s*(\d+[A-Z]*(?:\([^)]+\))*)\s*$/, text) ->
        [_, kind, rest] = m
        "#{prefix(kind)}.#{rest}"

      m = Regex.run(~r/^\s*Sch\.\s*(\d+[A-Z]*)\s+para\.\s*(\d+[A-Z]*(?:\([^)]+\))*)\s*$/, text) ->
        [_, sch, para] = m
        "sch.#{sch}.para.#{para}"

      true ->
        nil
    end
  end

  defp prefix("art" <> _), do: "reg"
  defp prefix("reg" <> _), do: "reg"
  defp prefix(_), do: "s"
end
