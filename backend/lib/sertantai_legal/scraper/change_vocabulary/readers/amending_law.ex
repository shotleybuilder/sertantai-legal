defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw do
  @moduledoc """
  The amending law's own text as claims — the primary source (change
  vocabulary CV-03; Jason 2026-10-21: "The actual legal text is primary").

  Each stored `Amendment.Rule` (the amending law's instruction or repeals
  table entry read by `Amendment.Reader`) is one change per target, keyed
  `source law:source provision`. Claims (source `:law_text`): `operation`,
  `level`, `by` (the amending law), `territory` (where the amending law
  applies, by its own application clause: `AmendingLaw.Extent`, CV-07). Its date (source `:commencement`) is
  when the amending provision came into force by the amending law's own
  text — its commencement clause and the orders read
  (`Commencement.Evaluator` over the text rules; the feed's
  coming-into-force records are derived, the feed reader's).

  Targets: those the amended law holds, then — a rule lists the
  provisions its words name and their parents ("s.284(3)", "s.284(3)(i)")
  — a quoted provision change on the top-most (no listed provision above
  it: its sub-provisions follow it); any other change on the deepest named
  (no listed provision below it: "subsection (6)(e) is omitted" is
  s.15(6)(e), never s.15(6) — CV-S06 B5).

  Pure: the rules come in as data (`Amendment.Store`, `Commencement.Store`
  in the caller).
  """

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim
  alias SertantaiLegal.Scraper.Commencement.{Evaluator, Order}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingCommencement
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw.Dropped
  alias SertantaiLegal.Scraper.Commencement.Rule, as: CRule
  alias SertantaiLegal.Scraper.LatRef

  @doc """
  Claim sets `{key, target, claims}` from the rules amending a law, dated
  by `commencement` (amending law → its `Commencement.Rule`s).
  """
  @spec read(
          [Rule.t()],
          %{String.t() => [CRule.t()]},
          [String.t()] | nil,
          %{String.t() => SertantaiLegal.Scraper.AmendingLaw.Extent.t()}
        ) ::
          [{String.t(), String.t(), [Claim.t()]}]
  def read(rules, commencement \\ %{}, known \\ nil, extents \\ %{}) do
    known = known && MapSet.new(known)

    # where a provision's quote and its named place reach one row, the
    # quote says what it is ("for paragraph (a) substitute— (a) …": the
    # row (a) substituted whole, not words in it; CV-S06 round 4)
    quoted =
      for %Rule{treatment: :quoted, source: %{law: law, ref: ref}} = r <- rules,
          t <- targets(r, known),
          into: MapSet.new(),
          do: {"#{law}:#{ref}", t}

    # one provision making several operations on one row ("after “a
    # notifier” add “or applicant” and for “2001” substitute “2015”": NISR
    # 2015/339 reg.34(2)(b)) makes a record of each, its key the provision's
    # and the operation (`provision_key/1` reads the provision back; CV-S07
    # round 3)
    several =
      for %Rule{source: %{law: law, ref: ref}} = r <- rules,
          t <- targets(r, known),
          r.treatment == :quoted or not MapSet.member?(quoted, {"#{law}:#{ref}", t}),
          reduce: %{} do
        acc ->
          Map.update(
            acc,
            {"#{law}:#{ref}", t},
            MapSet.new([r.operation]),
            &MapSet.put(&1, r.operation)
          )
      end

    # a target the amended law doesn't contain is a misread, not a fact
    records =
      for %Rule{source: %{law: law, ref: ref}} = r <- rules,
          target <- targets(r, known),
          r.treatment == :quoted or not MapSet.member?(quoted, {"#{law}:#{ref}", target}) do
        provision = "#{law}:#{ref}"

        key =
          if MapSet.size(Map.get(several, {provision, target}, MapSet.new())) > 1,
            do: "#{provision}##{r.operation}",
            else: provision

        {key, target,
         Enum.concat([
           Claim.new(:law_text, :operation, r.operation, key),
           Claim.new(:law_text, :level, level(r, target), key),
           Claim.new(:law_text, :by, law, key),
           AmendingCommencement.claims(Map.get(commencement, law, []), ref, key),
           # where the amending law applies (its application clause; CV-07),
           # or the amending provision's own (CV-S05 round 7)
           Claim.new(
             :law_text,
             :territory,
             applies_to(r.source.text) || application(extents, law, ref),
             key
           )
         ])}
      end

    records ++ dropped(rules, commencement, known)
  end

  # the rows a whole substitution's quote no longer makes: repealed by the
  # substituting law, the same day (CV-S09 round 7, `AmendingLaw.Dropped`)
  defp dropped(rules, commencement, known) do
    for {%Rule{source: %{law: law, ref: ref}}, row} <- Dropped.rows(rules, known) do
      key = "#{law}:#{ref}#dropped"

      {key, row,
       Enum.concat([
         Claim.new(:law_text, :operation, :repealed, key),
         Claim.new(:law_text, :level, :provision, key),
         Claim.new(:law_text, :by, law, key),
         AmendingCommencement.claims(Map.get(commencement, law, []), ref, key)
       ])}
    end
  end

  @doc """
  The amending provision a law-text record's key names ("law:element id"),
  without the operation one provision's several records carry
  ("UK_nisr_2015_339:regulation-34-2-b#inserted").
  """
  @spec provision_key(String.t()) :: String.t()
  def provision_key(key), do: key |> String.split("#", parts: 2) |> hd()

  # the version the instruction names: "in paragraph (b) as it applies to
  # Scotland" (Environment Act 1995 Sch.22 para.30(6), CV-S08 round 1)
  @applies_to ~r/\bas\s+(?:it|they)\s+appl(?:y|ies)\s+(?:in\s+relation\s+)?to\s+(England\s+and\s+Wales|Scotland|Northern\s+Ireland|Wales|England)\b/i
  @codes %{
    "england and wales" => "E+W",
    "scotland" => "S",
    "northern ireland" => "NI",
    "wales" => "W",
    "england" => "E"
  }

  defp applies_to(text) when is_binary(text) do
    case Regex.run(@applies_to, text) do
      [_, place] -> Map.get(@codes, place |> String.downcase() |> String.replace(~r/\s+/, " "))
      nil -> nil
    end
  end

  defp applies_to(_text), do: nil

  defp application(extents, law, ref) do
    case Map.get(extents, law) do
      %SertantaiLegal.Scraper.AmendingLaw.Extent{} = e ->
        SertantaiLegal.Scraper.AmendingLaw.Extent.application_at(e, List.wrap(Order.ref(ref)))

      %{application: a} ->
        a

      _ ->
        nil
    end
  end

  # the targets the amended law holds (a misread is not a fact): a quote's
  # top (its provisions follow it); a named place's readings each resolved
  # to the longest spelling held ("subsection (6)(e) is omitted" is
  # s.15(6)(e), never s.15(6) — CV-S06 B5; HSWA's CLML names s.28(3)(f)(i)
  # "section-28-f-i", so "paragraph (f)(i) of subsection (3)" is s.28(f)(i),
  # never also s.28(3) — CV-S06 seed 31 NEW); siblings stay apart
  # the whole law (`Reader.WholeLaw`): never a row's ref
  defp targets(%Rule{targets: ["*"]}, _known), do: ["*"]

  defp targets(%Rule{targets: targets} = r, known) do
    ts = Enum.uniq(targets)
    held? = &(known == nil or MapSet.member?(known, &1))

    if r.level == :provision and r.treatment == :quoted do
      ts = Enum.filter(ts, held?)
      Enum.reject(ts, fn t -> Enum.any?(tl(LatRef.ancestors(t)), &(&1 in ts)) end)
    else
      held = Enum.filter(ts, held?)

      ts
      |> Enum.reject(fn t -> Enum.any?(ts, &(&1 != t and spells?(t, &1))) end)
      |> Enum.flat_map(&longest_held(&1, held))
      |> Enum.uniq()
      |> deepest_only()
    end
  end

  # a definition's limb the law holds no row for: words in the provision
  # defining, never it whole (the target a held ancestor of the place named,
  # not a respelling of it: its last bracket differs)
  defp level(%Rule{treatment: :in_definition, level: :provision, targets: ts}, target) do
    ts = Enum.uniq(ts)
    fulls = Enum.reject(ts, fn t -> Enum.any?(ts, &(&1 != t and spells?(t, &1))) end)

    fallen? =
      target not in fulls and
        Enum.all?(
          Enum.filter(fulls, &spells?(target, &1)),
          &(List.last(brackets(&1)) != List.last(brackets(target)))
        )

    if fallen?, do: :words, else: :provision
  end

  defp level(%Rule{level: level}, _target), do: level

  # a place resolved beside a deeper one it holds is no change of its own
  # ("paragraphs (a)(i) and (ii) of paragraph (5)": never also (5))
  defp deepest_only(ts),
    do:
      Enum.reject(ts, fn t ->
        Enum.any?(ts, &(&1 != t and (spells?(t, &1) or t in tl(LatRef.ancestors(&1)))))
      end)

  # the held spellings of a full reading with the most brackets
  defp longest_held(full, held) do
    case Enum.filter(held, &(&1 == full or spells?(&1, full))) do
      [] ->
        []

      spellings ->
        most = spellings |> Enum.map(&length(brackets(&1))) |> Enum.max()
        Enum.filter(spellings, &(length(brackets(&1)) == most))
    end
  end

  # `t` is a shorter spelling of `u`: the same provision, its brackets a
  # subsequence of `u`'s ("s.28(f)(i)" and "s.28(3)" of "s.28(3)(f)(i)")
  defp spells?(t, u) do
    {pt, bt} = split(t)
    {pu, bu} = split(u)
    pt == pu and length(bt) < length(bu) and subsequence?(bt, bu)
  end

  defp subsequence?([], _), do: true
  defp subsequence?(_, []), do: false
  defp subsequence?([x | xs], [x | ys]), do: subsequence?(xs, ys)
  defp subsequence?(xs, [_ | ys]), do: subsequence?(xs, ys)

  defp brackets(t), do: elem(split(t), 1)

  defp split(t) do
    case Regex.run(~r/^([^()]+)((?:\([^()]+\))*)$/, t) do
      [_, head, bs] ->
        {head, Regex.scan(~r/\(([^()]+)\)/, bs, capture: :all_but_first) |> List.flatten()}

      nil ->
        {t, []}
    end
  end

  @doc "When the amending provision `ref` came fully into force by its law's own text (`AmendingCommencement`)."
  @spec commenced_on([CRule.t()], String.t()) :: Date.t() | nil
  defdelegate commenced_on(rules, ref), to: AmendingCommencement

  @doc "The amending provision's commencement by its law's text (`AmendingCommencement`)."
  @spec commencement([CRule.t()], String.t()) :: Evaluator.result() | nil
  defdelegate commencement(rules, ref), to: AmendingCommencement

  @doc "The law whose rule brought the provision fully into force (`AmendingCommencement`)."
  @spec commenced_by(Evaluator.result() | nil) :: String.t() | nil
  defdelegate commenced_by(result), to: AmendingCommencement
end
