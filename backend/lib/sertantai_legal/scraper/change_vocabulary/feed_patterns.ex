defmodule SertantaiLegal.Scraper.ChangeVocabulary.FeedPatterns do
  @moduledoc """
  The changes feed's patterns, in the feed reader's own terms (CV-S02b).
  Pure.

  The feed's literal strings are unbounded (3,689 effect types, 2,751
  provision texts) but its grammar is bounded. An effect is classed on each
  dimension the reader decides — one pattern per dimension and value:

  - `ref`: each affected ref's id grammar and the row refs the effect
    lands on (`section-N(+2) → s.N(+2)`; `schedule-N-part-N-paragraph-N →
    sch.N.pt.N`);
  - `verb`: the operation and the effect type's verb words
    (`substituted | substituted for`);
  - `level`: provision, or words and the word that makes it so;
  - `qualification`: each in-force entry's classes (`Qualification`), or
    prospective, or other with its words;
  - `staging`: the operation, the number of dated stages, a full (not
    partial) stage;
  - `linkage`: no ref (whole law, unplaced), one, siblings, a path in pieces;
  - `range`: none, spanned, ends kept;
  - `eu_finer`: an EU article's finer words (`para. N Point (x)`) and
    whether we hold the finer row.

  `excluded/1` sets aside what the catalogue doesn't hold: legislation.gov.uk's
  legacy dated types ("am (E) (1.1.2004)").

  An example is an effect with the context the reader needs (`encode/2`,
  `decode/1`) and what the reader made of it (`outcome/1`), with no
  legislation.gov.uk effect id anywhere (they trip push protection): the
  effect's id is "E".
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.{Claim, EffectVerb, Qualification, Ref}
  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.Feed
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect

  @type pattern :: {String.t(), String.t()}
  @type set :: {String.t(), String.t(), [Claim.t()]}
  @type context :: %{
          law: String.t(),
          order: [String.t()],
          xml_ids: %{String.t() => String.t()},
          rows: [String.t()]
        }

  @id "E"
  @eu ~w(eur eudr eudn)

  @doc "An example effect's id: never legislation.gov.uk's."
  @spec id() :: String.t()
  def id, do: @id

  @doc "Why an effect is outside the catalogue, or nil."
  @spec excluded(Effect.t()) :: String.t() | nil
  def excluded(%Effect{effect_id: nil}), do: "no effect id"

  def excluded(%Effect{type: type}) do
    if String.match?(type || "", ~r/\(\d{1,2}\.\d{1,2}\.\d{2,4}\)/), do: "legacy dated type"
  end

  @doc "The reader's output for an example: `Feed.read/7` over its context."
  @spec read(Effect.t(), context()) :: [set()]
  def read(%Effect{} = e, ctx),
    do: Feed.read([e], ctx.law, ctx.order, %{}, %{}, ctx.xml_ids, ctx.rows)

  @doc """
  The patterns of an effect, from the effect, the reader's claim sets for it
  and its context.
  """
  @spec patterns(Effect.t(), [set()], context()) :: [pattern()]
  def patterns(%Effect{} = e, sets, %{law: law} = ctx) do
    Enum.uniq(
      refs(e, ctx) ++
        [
          {"verb", verb(e, sets)},
          {"level", level(e, sets)},
          {"staging", staging(e, sets)},
          {"linkage", linkage(e, sets)},
          {"range", range(e, sets)}
        ] ++ qualifications(e) ++ eu_finer(e, sets, law)
    )
  end

  @doc "A pattern as one string: `dimension: value`."
  @spec key(pattern()) :: String.t()
  def key({dimension, value}), do: "#{dimension}: #{value}"

  # ── ref ──────────────────────────────────────────────────────────────

  # each ref's grammar and the row ref it is named as: our row's (its
  # `source_xml_id`), else the shared namer's; a ref another of the
  # effect's refs extends is a piece of that path, a range's ends span
  defp refs(%Effect{affected_refs: refs, affected_ranges: ranges}, ctx) do
    refs = List.wrap(refs)

    named =
      for id <- refs do
        cond do
          Enum.any?(refs, &String.starts_with?(&1, id <> "-")) -> "piece of a path"
          not (id =~ ~r/[-\d]/) -> "bare word"
          true -> named(id, ctx)
        end
        |> then(&{"ref", "#{id_shape(id)} → #{&1}"})
      end

    ends =
      for {a, b} <- ranges || [], id <- [a, b] do
        {"ref", "#{id_shape(id)} → #{named(id, ctx)} (range end)"}
      end

    named ++ ends
  end

  defp named(id, %{law: law, xml_ids: xml_ids}) do
    case {Map.get(xml_ids, id), Ref.from_clml(id, law)} do
      {nil, nil} -> "none"
      {nil, ref} -> target_shape(ref)
      {row, ref} when row == ref -> target_shape(ref)
      {row, _} -> target_shape(row) <> " (our row's id)"
    end
  end

  @doc """
  An id's grammar: kind words kept, the number after a word `N`, the levels
  below it counted (`section-28-3-f` → `section-N(+2)`; `schedule-2-part-1`
  → `schedule-N-part-N`); a cross-heading's words `*`; a number before any
  word `?`.
  """
  @spec id_shape(String.t()) :: String.t()
  def id_shape(id) do
    id
    |> String.split("-")
    |> Enum.reduce([], fn
      # a cross-heading's id is its words: "crossheading-obtaining-of-information"
      _token, [{"crossheading", _} | _] = acc ->
        acc

      "crossheading", acc ->
        [{"crossheading", :words} | acc]

      token, acc ->
        cond do
          word?(token) -> [{token, :none} | acc]
          match?([{_, :none} | _], acc) -> [{elem(hd(acc), 0), 0} | tl(acc)]
          acc == [] -> [{"?", 0}]
          true -> [{elem(hd(acc), 0), elem(hd(acc), 1) + 1} | tl(acc)]
        end
    end)
    |> Enum.reverse()
    |> Enum.map_join("-", fn
      {w, :words} -> "#{w}-*"
      {w, :none} -> w
      {w, 0} -> "#{w}-N"
      {w, n} -> "#{w}-N(+#{n})"
    end)
  end

  # a kind word: lowercase letters, four or more, not a Roman number
  # ("section", "part", "crossheading"; never "a", "aa", "iv", "viii")
  defp word?(token), do: token =~ ~r/^[a-z]{4,}$/ and not (token =~ ~r/^[ivxlc]+$/)

  @doc """
  A row ref's grammar: numbers `N`, the levels in brackets counted
  (`s.28(3)(f)` → `s.N(+2)`; `art.Article 57(a)` → `art.Article N(+1)`;
  `sch.1.para.2` → `sch.N.para.N`); `*` and `?` as they are.
  """
  @spec target_shape(String.t()) :: String.t()
  def target_shape(target) when target in ["*", "?"], do: target

  def target_shape(target) do
    [head | brackets] = String.split(target, "(")
    head = Regex.replace(~r/\b(?:[A-Z]*\d+[A-Za-z]*|[IVXLC]+[A-Z]?|[A-Z])\b/u, head, "N")

    case length(brackets) do
      0 -> head
      n -> "#{head}(+#{n})"
    end
  end

  # ── verb, level ──────────────────────────────────────────────────────

  @objects ~r/^(?:words?|sums?|figures?|entry|entries|comma|semi-?colon|full stop|hyphen|symbol|punctuation|formula|number|label|definitions?)\b\s*/

  defp verb(%Effect{type: type}, sets) do
    words = type |> words() |> String.replace(@objects, "")
    "#{operation(sets)} | #{words}"
  end

  # the effect makes no change (a commencement with no dated stage)
  defp operation([]), do: "no change"
  defp operation(sets), do: inspect(claim(sets, :operation))

  defp level(_effect, []), do: "no change"

  defp level(%Effect{type: type}, sets) do
    case claim(sets, :level) do
      :words ->
        words = words(type)

        cond do
          words =~ ~r/\bheading\b/ -> "words | heading"
          true -> "words | " <> (words |> String.split() |> List.first("") |> String.trim())
        end

      level ->
        inspect(level)
    end
  end

  # the effect type after the reader's word mapping, its references and
  # numbers dropped: "Words in s. 3(1) subst." → "words in substituted"
  @abbreviations ~w(s ss reg regs r rr art arts sch schs para paras pt pts ch si -)

  defp words(type) do
    (EffectVerb.type(type) || "")
    |> String.downcase()
    |> String.replace(~r/\([^)]*\)/, " ")
    |> String.split()
    |> Enum.reject(&(&1 =~ ~r/[\d.\[\]]|^\W+$/u or &1 in @abbreviations))
    |> Enum.join(" ")
    # who made it is the affecting law's: "substituted by", "omitted by virtue of"
    |> String.replace(~r/\s*\bby(?: virtue of)?\b.*$/, "")
  end

  # the claim on the effect's own change (key "E"), else its first stage
  defp claim(sets, attribute) do
    own = Enum.filter(sets, fn {key, _, _} -> key == @id end)

    Enum.find_value(own ++ sets, fn {_, _, claims} ->
      Enum.find_value(claims, &(&1.attribute == attribute && &1.value))
    end)
  end

  # ── qualification, staging ───────────────────────────────────────────

  defp qualifications(%Effect{in_force: entries}) do
    for entry <- entries || [], class = qualification(entry), uniq: true do
      {"qualification", class}
    end
  end

  defp qualification(%{date: nil, prospective: true}), do: "prospective"
  defp qualification(%{date: nil}), do: nil

  # the reader's classes (`Qualification.classes/1`); other with its words
  defp qualification(%{qualification: q}) do
    case Qualification.classes(q) do
      ["other"] -> "other | " <> generalise(q)
      classes -> Enum.join(classes, " + ")
    end
  end

  # numbers and refs out of free text: "for s. 3(1) only" → "for s. N only"
  defp generalise(text) do
    text
    |> String.downcase()
    |> String.replace(~r/\([^)]*\)/, "")
    |> String.replace(~r/\d+[a-z]*/, "N")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp staging(%Effect{in_force: entries}, sets) do
    stages =
      for(%{date: %Date{} = d} = e <- entries || [], do: {d, e.qualification}) |> Enum.uniq()

    full = Enum.any?(stages, fn {_, q} -> not Qualification.partial?(q) end)

    count =
      case length(stages) do
        n when n < 3 -> "#{n}"
        _ -> "3+"
      end

    "#{operation(sets)} | stages #{count} | full stage #{full}"
  end

  # ── linkage, range ───────────────────────────────────────────────────

  defp linkage(%Effect{affected_refs: refs}, sets) do
    {bare, refs} = refs |> List.wrap() |> Enum.split_with(&(not (&1 =~ ~r/[-\d]/)))
    pieces? = Enum.any?(refs, fn r -> Enum.any?(refs, &String.starts_with?(&1, r <> "-")) end)
    deepest = Enum.reject(refs, fn r -> Enum.any?(refs, &String.starts_with?(&1, r <> "-")) end)
    targets = sets |> Enum.map(&elem(&1, 1)) |> Enum.uniq()

    base =
      cond do
        targets == ["*"] -> "whole law"
        refs == [] -> "no ref"
        pieces? and length(deepest) > 1 -> "pieces and siblings"
        pieces? -> "pieces"
        length(refs) > 1 -> "siblings"
        true -> "one"
      end

    base <>
      if(bare != [], do: " + bare word", else: "") <>
      if(targets == ["?"], do: " → ?", else: "")
  end

  defp range(%Effect{affected_ranges: ranges}, sets) do
    cond do
      (ranges || []) == [] -> "none"
      claim(sets, :ranged) == true -> "spanned"
      true -> "ends kept"
    end
  end

  # ── EU finer forms ───────────────────────────────────────────────────

  defp eu_finer(%Effect{affected_refs: refs, affected_provisions: text}, sets, law) do
    with true <- eu?(law) and length(List.wrap(refs)) == 1,
         [_, tail] <- Regex.run(~r/^\s*Art\.\s*\w+\s*(.*)$/u, text || ""),
         tail when tail != "" <- String.trim(tail) do
      held =
        cond do
          claim(sets, :finer_unheld) != nil -> "unheld"
          Enum.any?(sets, fn {_, t, _} -> t =~ ~r/^art\.Article [^(]+\(/ end) -> "held"
          true -> "article"
        end

      [{"eu_finer", "#{finer_shape(tail)} → #{held}"}]
    else
      _ -> []
    end
  end

  # "para. 6 Point (b)" → "para. N Point (x)"; ".2 L2" → ".N LN"
  defp finer_shape(tail) do
    tail
    |> String.replace(~r/\d+[a-z]?/, "N")
    |> String.replace(~r/\([A-Za-z]{1,5}\)/, "(x)")
    |> String.replace(~r/\b[A-Za-z]{1,5}\)/, "x)")
    |> String.replace(~r/\s+/, " ")
  end

  defp eu?(law), do: Enum.at(String.split(law || "", "_"), 1) in @eu

  # ── examples ─────────────────────────────────────────────────────────

  @doc "An effect and its context as JSON, the effect id replaced by \"E\"."
  @spec encode(Effect.t(), context()) :: map()
  def encode(%Effect{} = e, ctx) do
    %{
      "law" => ctx.law,
      "effect" =>
        %{
          "type" => e.type,
          "affecting" => e.affecting,
          "affecting_provisions" => e.affecting_provisions,
          "affected_provisions" => e.affected_provisions,
          "affected_extent" => e.affected_extent,
          "effect_extent" => e.effect_extent,
          "territorial_application" => e.territorial_application,
          "applied" => e.applied,
          "requires_applied" => e.requires_applied,
          "in_force_date" => iso(e.in_force_date),
          "in_force_qualification" => e.in_force_qualification,
          "in_force_qualifications" => e.in_force_qualifications,
          "in_force" => for(f <- e.in_force || [], do: %{f | date: iso(f.date)} |> stringify()),
          "prospective" => e.prospective,
          "savings" => e.savings,
          "affected_refs" => e.affected_refs,
          "affected_ranges" => for({a, b} <- e.affected_ranges || [], do: [a, b])
        }
        |> Map.reject(fn {_, v} -> v in [nil, []] end),
      "order" => ctx.order,
      "xml_ids" => ctx.xml_ids,
      "rows" => ctx.rows
    }
  end

  @doc "An encoded example back to an effect and its context."
  @spec decode(map()) :: {Effect.t(), context()}
  def decode(%{"law" => law, "effect" => e} = example) do
    effect = %Effect{
      effect_id: @id,
      type: e["type"],
      affecting: e["affecting"],
      affecting_provisions: e["affecting_provisions"],
      affected_provisions: e["affected_provisions"],
      affected_extent: e["affected_extent"],
      effect_extent: e["effect_extent"],
      territorial_application: e["territorial_application"],
      applied: e["applied"],
      requires_applied: e["requires_applied"],
      in_force_date: date(e["in_force_date"]),
      in_force_qualification: e["in_force_qualification"],
      in_force_qualifications: e["in_force_qualifications"] || [],
      in_force:
        for f <- e["in_force"] || [] do
          %{
            date: date(f["date"]),
            prospective: f["prospective"],
            qualification: f["qualification"],
            applied: f["applied"]
          }
        end,
      prospective: e["prospective"],
      savings: e["savings"] || [],
      affected_refs: e["affected_refs"] || [],
      affected_ranges: for([a, b] <- e["affected_ranges"] || [], do: {a, b})
    }

    {effect,
     %{
       law: law,
       order: example["order"] || [],
       xml_ids: example["xml_ids"] || %{},
       rows: example["rows"] || []
     }}
  end

  @doc """
  What the reader made of an example, as JSON: each change's key, target
  and claims (`source.attribute` → value).
  """
  @spec outcome([set()]) :: [map()]
  def outcome(sets) do
    for {key, target, claims} <- sets do
      %{
        "key" => key,
        "target" => target,
        "claims" => Map.new(claims, fn c -> {"#{c.source}.#{c.attribute}", json(c.value)} end)
      }
    end
  end

  defp json(%Date{} = d), do: Date.to_iso8601(d)
  defp json(v) when is_boolean(v) or is_nil(v), do: v
  defp json(v) when is_atom(v), do: Atom.to_string(v)
  defp json(v) when is_list(v), do: Enum.map(v, &json/1)
  defp json(v), do: v

  defp stringify(map), do: Map.new(map, fn {k, v} -> {Atom.to_string(k), v} end)

  defp iso(nil), do: nil
  defp iso(%Date{} = d), do: Date.to_iso8601(d)

  defp date(nil), do: nil
  defp date(s), do: Date.from_iso8601!(s)
end
