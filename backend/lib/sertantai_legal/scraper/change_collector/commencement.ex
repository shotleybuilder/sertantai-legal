defmodule SertantaiLegal.Scraper.ChangeCollector.Commencement do
  @moduledoc """
  The commencement collector (lat-refactor LR-33, LR-34; commencement-rules
  CR-06): when the law and its provisions came into force, and which
  treatment decided it. Source `law`, operation `commenced`, `effect_type`
  the treatment, `effective_from` its date (nil for a known limit),
  `evidence` the clause's section_id or the metadata field, `affected_ref`
  the clause.

  - **The law** (`LawStart`): one law-level record (`section_id` nil).
  - **Its provisions**: the commencement evaluator over the law's own
    clause as rules (`OwnClause`) and, for rows its own feed doesn't date,
    its commencement orders (`Order`, CR-07) — one record per row a rule other than
    the law-level one reaches: `provision_dated` (fully in force on a date;
    its partial entries before it kept as in-force entries),
    `provision_qualified` (in force partly only), `provision_by_order` (left
    to orders, wholly or for the rest: J6). A sentence the reader can't resolve is one law-level
    `provision_unread` record.

  `LabelTimeline` takes the law's start from the law-level record and each
  row's start from its provision record; these records are never changes.
  Pure.
  """

  alias SertantaiLegal.Scraper.LatRef
  alias SertantaiLegal.Scraper.ChangeCollector.Record
  alias SertantaiLegal.Scraper.Commencement.{Evaluator, OwnClause}
  alias SertantaiLegal.Scraper.{LawStart}

  @doc """
  The law's commencement records from its `LawStart.input()`. `opts`:
  `orders:` the law's own commencement orders as rules (CR-07), which reach
  a row only where its own feed dates no commencement of it or an ancestor
  (`feed_dated:`, section_ids: effects first).
  """
  @spec records(String.t(), LawStart.input(), keyword()) :: [Record.t()]
  def records(law_name, input, opts \\ []) do
    %{law: law, rules: rules, unread: unread} = OwnClause.read(law_name, input)
    rows = Map.get(input, :rows, [])
    ctx = rows |> OwnClause.context() |> Map.put(:made, Map.get(input, :made))
    law_rule = Enum.find(rules, &(&1.scope == :all))
    orders = Keyword.get(opts, :orders, [])
    feed_dated = Keyword.get(opts, :feed_dated, MapSet.new())

    rules_for = fn sid ->
      if orders == [] or Enum.any?(LatRef.ancestors(sid), &MapSet.member?(feed_dated, &1)),
        do: rules,
        else: rules ++ orders
    end

    provisions =
      for row <- rows,
          r =
            Evaluator.evaluate(
              rules_for.(row.section_id),
              row.section_id,
              Map.put(ctx, :extent, row[:extent_code])
            ),
          rec = provision(law_name, row.section_id, r, law_rule),
          rec != nil,
          do: rec

    unread =
      for g <- unread,
          do:
            record(law_name, nil, :provision_unread, %{full_from: nil, entries: []}, %{
              law: law_name,
              ref: g.evidence,
              text: g.text
            })

    [law_record(law_name, law) | provisions] ++
      Enum.uniq_by(unread, &{&1.evidence, &1.affected_ref})
  end

  # a row only the law-level rule reaches takes the law's start (no record);
  # a law commenced wholly by order leaves every row to orders
  defp provision(law_name, sid, r, law_rule) do
    own = Enum.reject(Enum.map(r.entries, & &1.rule) ++ r.undated, &(&1 == law_rule))
    by_order? = Enum.any?(r.undated, &match?({:appointed, _}, &1.when))
    dated? = Enum.any?(r.entries, & &1.date)

    cond do
      own == [] and not match?(%{treatment: :by_order}, law_rule) ->
        nil

      r.full_from != nil ->
        record(law_name, sid, :provision_dated, r, decider(r, law_rule).source)

      # partly in, the rest left to orders: J6 (LR-34 D1 b), its partial
      # entries kept as facts
      dated? and by_order? ->
        record(law_name, sid, :provision_by_order, r, decider(r, law_rule).source)

      dated? ->
        record(law_name, sid, :provision_qualified, r, decider(r, law_rule).source)

      by_order? ->
        rule = Enum.find(own, law_rule, &match?({:appointed, _}, &1.when))
        record(law_name, sid, :provision_by_order, r, rule.source)

      true ->
        nil
    end
  end

  # the rule that brought the row fully into force, else its first dated
  # one (the law-level rule only where nothing else did)
  defp decider(%{entries: entries, full_from: full}, law_rule) do
    dated = Enum.filter(entries, & &1.date)

    e =
      (full && Enum.find(dated, &(&1.date == full and &1.rule != law_rule))) ||
        (full && Enum.find(dated, &(&1.date == full))) ||
        Enum.find(dated, &(&1.rule != law_rule)) || hd(dated)

    e.rule
  end

  defp law_record(law_name, %LawStart{} = law) do
    %Record{
      base(law_name, nil, law.treatment, law.date, law.evidence)
      | affected_ref: law.text,
        in_force: if(law.date, do: [entry(law.date, nil)], else: [])
    }
  end

  defp record(law_name, sid, treatment, r, source) do
    by = source.law || law_name

    %Record{
      base(law_name, sid, treatment, r.full_from, evidence(by, source.ref))
      | affected_ref: source.text,
        dated_by_law: if(r.full_from, do: by),
        in_force: for(e <- Evaluator.in_force(r), do: entry(e.date, e.qualification))
    }
  end

  defp base(law_name, section_id, treatment, date, evidence) do
    %Record{
      law_name: law_name,
      section_id: section_id,
      evidence: evidence || Atom.to_string(treatment),
      via: ["instrument"],
      source: "law",
      affecting_law: law_name,
      dated_by_law: if(date, do: law_name),
      operation: "commenced",
      effect_type: Atom.to_string(treatment),
      effective_from: date
    }
  end

  defp entry(date, qualification),
    do: %{
      "date" => Date.to_iso8601(date),
      "applied" => true,
      "prospective" => false,
      "qualification" => qualification
    }

  # the clause's section_id ("UK_x:reg.1(2)"); metadata evidence as is
  defp evidence(_law_name, nil), do: nil

  defp evidence(law_name, ref) do
    if ref =~ ~r/^(?:s|reg|art|rule|pt|sch)\./, do: "#{law_name}:#{ref}", else: ref
  end
end
