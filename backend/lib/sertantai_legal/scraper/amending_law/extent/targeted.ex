defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Targeted do
  @moduledoc """
  Target-named extent statements (CV-S05f): an amending law stating the
  extent of the changes it makes to a named target of the amended law, not
  of its own provision — "The repeal of section 4(8) extends also to
  Scotland" (SOCPA 2005 Sch.7 para 27(4): the paragraph repeals RTA 1988
  s.4(6) to (8), and only s.4(8)'s repeal reaches Scotland), "The repeal of
  the Arbitration Act 1975 extends only to England and Wales and Northern
  Ireland" (ukpga 1996/23 s.108(4)), "Note: The repeals in the Clean Air Act
  1956, … do not extend to Scotland" (EPA 1990 Sch.16 Pt III).

  Each statement is `%{kind, place, scope, law, refs}`:

  - `kind`, `place`: as an extent list's (`:also`, `:only`, `:not`,
    `:named`);
  - `scope`: the amending provisions whose changes it speaks of — a
    Schedule paragraph's statement its paragraph, a Schedule (or Part)'s
    note that Schedule (Part), the law's own Schedule a list names ("the
    following provisions in Schedule 20"), else `"*"` (every provision);
  - `law`: the amended law as named (its title, no "the", no chapter), or
    nil — none named: the law the scope's own instructions amend;
  - `refs`: the targets, in the amended law's ref grammar (`s.4(8)`), or
    `["*"]` (the whole law).

  `Extent.Lookup.of_change/3` applies them to a change by its law and
  target. Never read (left to `Extent.Unread`, the bound withheld): a
  statement inside an exception or after a lead-in ("Except as provided in
  Part II …, the repeal of …"), a relative clause ("…, which extends to"),
  "so far as it is applied by", the law's own changes ("made by this Act").
  Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Places, Units}
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.LawStart.Clause

  @type t :: %{
          kind: :also | :only | :not | :named,
          place: String.t(),
          scope: String.t(),
          law: String.t() | nil,
          refs: [String.t()]
        }

  @place_list Places.place_list()
  @change "(?:amendments?|repeals?|revocations?)"

  @form Regex.compile!(
          "^\\s*(?:Note:\\s*)?(?:The|An|Any)\\s+#{@change}(?:\\s*(?:,|and|or)\\s*#{@change})*\\s+(?:of|in|to|in\\s+respect\\s+of)\\s+(?<subject>.+?)\\s+(?:(?<not>(?:does|do|shall)\\s+not)\\s+extend\\s+to\\s+(?<p1>(?>#{@place_list}))|(?:shall\\s+)?extends?\\s+(?<also>also\\s+)?(?<only>only\\s+)?to\\s+(?<p2>(?>#{@place_list}))(?<only2>\\s+only)?)\\s*(?:(?<dash>[—–])\\s*(?<list>.+?)|\\.)?\\s*$",
          "su"
        )

  # the next subject of a sentence naming several: ", the repeal in …"
  @next_subject Regex.compile!(
                  "\\s*(?:,\\s*(?:and\\s+)?|\\s+and\\s+)(?:the|an?)\\s+#{@change}\\s+(?:of|in|to)\\s+",
                  "u"
                )

  # words that make it no plain statement of the targets' extent
  @not_plain ~r/\b(?:made\s+by|by\s+this|this\s+(?:Act|Part|Schedule|Order|Regulations)|these\s+Regulations|so\s+far\s+as|other\s+than|except|which|subject\s+to|any\s+other)\b/iu

  # a law's title, after "the" or at the start ("the Alkali, &c. Works
  # Regulation Act 1906", "the Companies (Audit, …) Act 2004"), with its
  # chapter aside after it ("(c. 64)")
  @title ~r/(?:^|\bthe\s+)(?<title>[A-Z](?:[\w,'’&\-\s]|\.(?!\s*$)|\((?!c\.\s)[^()]*\))*?\s(?:Act|Regulations|Order|Rules)(?:\s+\(Northern\s+Ireland\))?\s+\d{4})(?:\s*\([^()]*\))?/u

  @provision_word ~r/\b(?:sections?|regulations?|articles?|rules?|paragraphs?|Schedules?|Parts?|Chapters?)\s+[\dIVXL]/u

  @doc "The law's target statements, each sentence at the deepest provision stating it."
  @spec lists(Doc.t()) :: [t()]
  def lists(%Doc{} = doc) do
    found =
      for id <- doc.ids,
          ref = Order.ref(id),
          ref != nil and not String.contains?(ref, "("),
          unit <- Units.units(doc, id),
          unit =~ ~r/\b#{@change}\b/iu,
          s <- Clause.sentences(unit),
          found = statements(s, ref),
          found != nil,
          do: {s, ref, found}

    # (a Schedule Part's words hold its paragraphs' sentences too: each
    # sentence at the deepest provision, in document order)
    deepest =
      found
      |> Enum.group_by(&elem(&1, 0))
      |> Map.new(fn {s, at} -> {s, Enum.max_by(at, &depth(elem(&1, 1)))} end)

    found
    |> Enum.filter(fn {s, _, _} = f -> deepest[s] == f end)
    |> Enum.flat_map(&elem(&1, 2))
    |> Enum.uniq()
  end

  defp depth(ref), do: length(String.split(ref, "."))

  @doc "The target statements one sentence of the provision `ref` makes; nil when none is plainly read."
  @spec statements(String.t(), String.t()) :: [t()] | nil
  def statements(sentence, ref) do
    with %{"subject" => subject} = m <- Regex.named_captures(@form, sentence),
         false <- Regex.match?(@not_plain, subject),
         {kind, place} when is_binary(place) <- kind(m),
         {scope, targets} <- targets(subject, m, ref),
         false <- targets == [] or Enum.any?(targets, &(&1.refs == [])) do
      for t <- targets, do: Map.merge(%{kind: kind, place: place, scope: scope}, t)
    else
      _ -> nil
    end
  end

  defp kind(%{"not" => n, "p1" => p}) when n != "", do: {:not, Places.places(p)}
  defp kind(%{"also" => a, "p2" => p}) when a != "", do: {:also, Places.places(p)}

  defp kind(%{"only" => o, "only2" => o2, "p2" => p}) when o != "" or o2 != "",
    do: {:only, Places.places(p)}

  defp kind(%{"p2" => p}), do: {:named, Places.places(p)}

  # the list form: "The repeals of the following provisions in Schedule 20
  # extend to England and Wales only— (a) section 67 of the Agriculture
  # Act 1967, …" (ERRA 2013 s.102(6))
  defp targets(subject, %{"dash" => d, "list" => list}, ref) when d != "" do
    case Regex.run(
           ~r/^the\s+following\s+(?:provisions|enactments)(?:\s+in\s+Schedule\s+(\d+[A-Z]*))?$/u,
           subject
         ) do
      [_, sch] -> {"sch.#{sch}", named(list)}
      [_] -> {scope(ref), named(list)}
      nil -> nil
    end
  end

  # the law's own provisions, then the laws they change: "The repeals in
  # Part 4 of Schedule 37 relating to— (a) the Bankers' Books Evidence Act
  # 1879 (c. 11), …" (ukpga 2003/44 s.337) — scope that Part
  defp targets(subject, _m, ref) do
    cond do
      subject =~ ~r/\bfollowing\b/u ->
        nil

      match = Regex.run(~r/^(.+?)\s+relating\s+to\b[\s—–]*(.+)$/su, subject) ->
        [_, own, laws] = match

        with [scope] <- RefList.parse(own),
             [_ | _] = named <- named(laws),
             true <- Enum.all?(named, &(&1.law != nil)),
             do: {scope, named},
             else: (_ -> nil)

      true ->
        named = subject |> String.split(@next_subject) |> Enum.flat_map(&named/1)

        # no law named: the provisions of the law a Schedule paragraph
        # amends ("The repeal of section 4(8)", SOCPA Sch.7 para 27(4)) —
        # elsewhere they are the law's own ("The amendment in Schedule 1
        # extends to …", SI 2012/2404 reg.4: `Extent.Named`'s)
        if Enum.any?(named, &(&1.law == nil)) and not paragraph?(scope(ref)),
          do: nil,
          else: {scope(ref), named}
    end
  end

  defp paragraph?(scope), do: scope =~ ~r/\.para\.[^.]+$/

  # a Schedule paragraph's statement: the paragraph; a Schedule's or a
  # Part's: itself; a section's: the whole law
  defp scope("sch." <> _ = ref) do
    case Regex.run(~r/^(sch\.[^.]+(?:\.pt\.[^.]+)?\.para\.[^.]+)/, ref) do
      [_, para] -> para
      nil -> ref
    end
  end

  defp scope(_ref), do: "*"

  # each law named with the provisions before it ("section 15 of the …
  # Act 2004" → s.15; "the Clean Air Act 1956" → the whole law); none
  # named, the provisions of the scope's own law
  defp named(text) do
    text = String.trim(text)

    case Regex.scan(@title, text, return: :index) do
      [] ->
        if text =~ ~r/\b(?:Act|Regulations|Order|Rules)\b/u,
          do: [%{law: nil, refs: []}],
          else: [%{law: nil, refs: refs(text)}]

      matches ->
        {out, _} =
          Enum.map_reduce(matches, 0, fn [{at, len}, {t_at, t_len} | _], from ->
            before = binary_part(text, from, at - from)
            title = binary_part(text, t_at, t_len)
            {%{law: title, refs: law_refs(before)}, at + len}
          end)

        out
    end
  end

  # the provisions named before a law ("paragraph 32 of Schedule 2 to");
  # none: the whole law ("the repeal of the …", "a provision of the …")
  defp law_refs(before) do
    before =
      before
      |> String.replace(~r/^[\s,;]*(?:and\s+)?(?:\(?[a-z]{1,2}\)\s*)?/u, "")
      |> String.replace(~r/\s*(?:of|to|in)\s*(?:the\s*)?$/u, "")

    if before =~ @provision_word, do: refs(before), else: ["*"]
  end

  defp refs(text), do: RefList.parse(text)
end
