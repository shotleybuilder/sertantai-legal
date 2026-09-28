defmodule SertantaiLegal.Scraper.LiveStatus do
  @moduledoc """
  Pure decision of a law's `live` status from its legislation.gov.uk
  "changes affected" revocation rows (live status parse session, 2026-09-28).

  Each row is `%{by, affect, target, applied}` — the revoking law, the affect
  text, the target ("Regulations", "Act", "s. 3", …) and the Applied column.

  Rules:

  - **Revocation** — the affect repeals or revokes; a commencement of repeals
    ("Appointed day(s) for spec. repeals …") is not a revocation.
  - **Whole** — a revocation of the whole instrument ("in full", or a bare
    repeal/revoke of a whole-instrument target). When the law's changes feed
    was read and has no whole-instrument revocation behind the row
    (`feed: "unmatched"`), the row is not whole: the feed is authoritative
    (REACH carried a blank-target "repeal" row that is only annex repeals). Not whole: partial markers
    ("in part", "in pt", "words", …), overseas-territory revocations
    ("(Pitcairn)", …) and prospective revocations ("(prosp.)").
  - **Applied or not** — a whole revocation counts whether or not
    legislation.gov.uk has applied it to the text; `revoked_unapplied`
    records that it has not.
  - **Territorial** — a revocation reaches where legislation.gov.uk's changes
    feed says it applies (`AffectingTerritorialApplication`, else
    `AffectingEffectsExtent`; see `LegislationGovUk.ChangesFeed`). Without
    feed data: an extent marker in the affect ("revoked (S.)"), else a
    devolved revoker's type (SSI → S, WSI → W, NISR → NI), else the revoker's recorded extent,
    else (UK-level revoker not in the DB) the whole law. When the revokers
    together leave part of the law's jurisdiction uncovered, the law is
    `territorial` (live: Part Revocation). Where the law applies is its
    devolved type's jurisdiction, else a title marker ("(Wales)", …), else its
    **application** (`ctx.law_application`: its own application clause via
    `ApplicationClause`, or fractalaw's), else the `AffectedExtent` of its
    whole-instrument effects, else its recorded extent. A territorial result
    resting only on extent is flagged `application_unknown`: extent is not
    application, so it is not a determination until the law's application
    clause is read (LAT parse).

  The revoker's date is its made date (`revoker_made_date`), not the
  commencement of the revoking provision. The decision never infers a whole
  revocation from partial rows.
  """

  defmodule Decision do
    @moduledoc "A law's live status decision: `live`, `kind`, `description` and JSON-safe `evidence`."
    @enforce_keys [:live, :kind, :description, :evidence]
    defstruct @enforce_keys

    @type kind :: :in_force | :part_revoked | :territorial | :revoked | :revoked_unapplied
    @type t :: %__MODULE__{
            live: String.t(),
            kind: kind(),
            description: String.t(),
            evidence: map()
          }
  end

  @live_in_force "✔ In force"
  @live_part_revoked "⭕ Part Revocation / Repeal"
  @live_revoked "❌ Revoked / Repealed / Abolished"

  @type row :: %{
          required(:by) => String.t(),
          required(:affect) => String.t(),
          required(:target) => String.t(),
          required(:applied) => String.t(),
          optional(:feed) => String.t() | nil,
          optional(:affected_extent) => String.t() | nil,
          optional(:effect_extent) => String.t() | nil,
          optional(:territorial_application) => String.t() | nil
        }
  @type revoker :: %{extent: String.t() | nil, date: Date.t() | nil}
  @type context :: %{
          required(:law_type) => String.t() | nil,
          required(:law_extent) => String.t() | nil,
          optional(:law_title) => String.t() | nil,
          optional(:law_application) => [String.t()] | nil,
          optional(:law_clause_read) => boolean(),
          optional(:law_text_repealed) => boolean(),
          optional(:law_extent_source) => String.t() | nil,
          optional(:parent_regions) => [String.t()] | nil,
          optional(:trust_revoker_extent) => boolean(),
          required(:revokers) => %{String.t() => revoker()}
        }

  @whole_targets ~w(regulations regulation act order rules scheme measure charter byelaws instrument directive decision)
  @partial ~r/in part|\bin pt\b|partial|except|words? |entry |entries |comma |power to/
  @overseas ~r/\((pitcairn|sovereign base areas|british indian ocean territory|isle of man|guernsey|jersey|channel islands|gibraltar|falkland islands|st\.? helena|bermuda|montserrat|anguilla|cayman islands|(british )?virgin islands|turks and caicos islands)/
  @extent_marker ~r/\(((?:e|w|s|n\.?\s?i)(?:\.?\s?(?:\+|,)?\s?(?:e|w|s|n\.?\s?i))*)\.?\)/
  @all_regions ~w(E W S NI)
  @devolved %{
    "ssi" => ["S"],
    "asp" => ["S"],
    "wsi" => ["W"],
    "anaw" => ["W"],
    "asc" => ["W"],
    "mwa" => ["W"],
    "nisr" => ["NI"],
    "nisro" => ["NI"],
    "nia" => ["NI"],
    "apni" => ["NI"],
    "nisi" => ["NI"]
  }

  @doc "Is this affect a revocation (repeal/revoke), excluding commencements of repeals?"
  @spec revocation?(String.t() | nil) :: boolean()
  def revocation?(affect) do
    a = normalise(affect)

    (String.contains?(a, "repeal") or String.contains?(a, "revoke") or a in ["rev", "rep"]) and
      not commencement?(a)
  end

  @doc "Is this row an in-force revocation of the whole instrument (in some jurisdiction)?"
  @spec whole?(map()) :: boolean()
  def whole?(%{affect: affect, target: target} = row) do
    a = normalise(affect)
    t = normalise(target)

    Map.get(row, :feed) != "unmatched" and revocation?(a) and not Regex.match?(@partial, a) and
      not Regex.match?(@overseas, a) and
      not String.contains?(a, "prosp") and
      (String.contains?(a, "in full") or t == "" or t in @whole_targets or
         String.contains?(t, "whole instrument"))
  end

  @doc "Decide a law's live status from its revocation rows and context."
  @spec decide([row()], context()) :: Decision.t()
  def decide(rows, ctx) do
    revocations = Enum.filter(rows, &revocation?(&1.affect))
    whole = Enum.filter(revocations, &whole?/1)

    cond do
      revocations == [] -> simple(:in_force, @live_in_force, "In force")
      whole == [] -> simple(:part_revoked, @live_part_revoked, "Part revoked")
      true -> decide_whole(whole, ctx)
    end
  end

  @doc "The metadata override: a title marker or document status of revoked/repealed."
  @spec from_metadata(:title | :doc_status, String.t()) :: Decision.t()
  def from_metadata(source, word) do
    desc = if source == :title, do: "#{word} (from title)", else: word

    %Decision{
      live: @live_revoked,
      kind: :revoked,
      description: desc,
      evidence: %{"kind" => "revoked", "source" => Atom.to_string(source)}
    }
  end

  @doc """
  A decision from a bare `live` value, for a law with no stored revocation
  rows (e.g. a legacy record): keeps the value, asserts no revokers.
  """
  @spec from_live(String.t() | nil) :: Decision.t()
  def from_live(@live_revoked), do: simple(:revoked, @live_revoked, "Revoked")
  def from_live(@live_part_revoked), do: simple(:part_revoked, @live_part_revoked, "Part revoked")
  def from_live(_), do: simple(:in_force, @live_in_force, "In force")

  @doc "A row from an `Amending` amendment map (`name`, `affect`, `target`, `applied?`)."
  @spec row_from_amendment(map()) :: row()
  def row_from_amendment(a) do
    %{
      by: a.name,
      affect: a[:affect] || "",
      target: a[:target] || "",
      applied: a[:applied?] || "",
      feed: a[:feed],
      affected_extent: a[:affected_extent],
      effect_extent: a[:effect_extent],
      territorial_application: a[:territorial_application]
    }
  end

  @doc """
  Flatten the stored `🔻_rescinded_by_stats_per_law` JSONB into rows.

  Legacy-imported rows have no `affect`: the whole effect text is in `target`
  ("revoked", "s. 15(1) repealed (1.10.1994)", "Regulations revoked by
  S.I. 2019/458 …"). They are split at the first repeal/revoke word into
  target (before) and affect (from the word on).
  """
  @spec rows_from_stats(map() | nil) :: [row()]
  def rows_from_stats(nil), do: []

  def rows_from_stats(stats) when is_map(stats) do
    for {name, entry} <- Enum.sort(stats), d <- Map.get(entry, "details") || [] do
      {target, affect} = split_legacy(d["target"] || "", d["affect"])

      %{
        by: name,
        affect: affect,
        target: target,
        applied: d["applied"] || "",
        feed: d["feed"],
        affected_extent: d["affected_extent"],
        effect_extent: d["effect_extent"],
        territorial_application: d["territorial_application"]
      }
    end
  end

  defp split_legacy(target, affect) when is_binary(affect) and affect != "", do: {target, affect}

  defp split_legacy(text, _) do
    case Regex.split(~r/(?=\b(?:repeal|revok|rev\b|rep\b))/i, text, parts: 2) do
      [before, verb_on] -> {String.trim(before), String.trim(verb_on)}
      [_] -> {text, ""}
    end
  end

  @doc ~s[The regions (E, W, S, NI) of an extent string such as "E+W+S", "GB" or "UK"; nil when unknown.]
  @spec regions(String.t() | nil) :: [String.t()] | nil
  def regions(nil), do: nil

  def regions(extent) do
    case extent |> String.upcase() |> String.replace(~r/[\s.]/, "") do
      "" ->
        nil

      "S+A+M+E+A+S+A+F+F+E+C+T+E+D" ->
        nil

      "UK" ->
        @all_regions

      "GB" ->
        ~w(E W S)

      e ->
        e
        |> String.split(~r/[+,]/, trim: true)
        |> Enum.filter(&(&1 in @all_regions))
        |> nil_if_empty()
    end
  end

  # --- whole revocations ---

  defp decide_whole(whole, ctx) do
    revokers = Map.get(ctx, :revokers) || %{}
    affected = whole |> Enum.flat_map(&(regions(&1[:affected_extent]) || [])) |> nil_if_empty()

    {law_regions, law_basis} =
      ctx[:law_type]
      |> law_regions(ctx[:law_title], ctx[:law_application], affected, ctx[:law_extent])
      |> bound_by_parents(ctx[:parent_regions])

    trust? = Map.get(ctx, :trust_revoker_extent, false)

    entries =
      whole
      |> Enum.map(fn r ->
        {regions, basis} = revoker_regions(r, revokers, trust?)
        {r, regions, basis}
      end)

    covered = entries |> Enum.flat_map(fn {_, regs, _} -> regs end) |> Enum.uniq()

    remaining =
      if law_regions, do: sort_regions(law_regions -- covered), else: []

    # Regions a UK-level revoker's recorded extent leaves uncovered, when that
    # extent is not trusted: evidence for review, not a territorial decision.
    extent_gap =
      if law_regions && !trust? do
        recorded =
          Enum.flat_map(entries, fn {r, regs, basis} ->
            if basis == "uk_level_revoker",
              do: revokers |> Map.get(r.by, %{}) |> Map.get(:extent) |> regions(),
              else: regs
          end)

        sort_regions(law_regions -- recorded) -- remaining
      else
        []
      end

    applied? = Enum.any?(whole, &applied?(&1.applied))
    savings? = Enum.any?(whole, &String.contains?(normalise(&1.affect), "saving"))
    by = whole |> Enum.map(& &1.by) |> Enum.uniq()

    # legislation.gov.uk has removed (almost) all the text: revoked in full
    text_repealed? = Map.get(ctx, :law_text_repealed, false) == true

    kind =
      cond do
        remaining != [] and not text_repealed? -> :territorial
        applied? or text_repealed? -> :revoked
        true -> :revoked_unapplied
      end

    remaining = if kind == :territorial, do: remaining, else: []

    revoked_regions =
      if law_regions,
        do: sort_regions(Enum.filter(covered, &(&1 in @all_regions)) -- remaining),
        else: nil

    # A territorial remainder resting only on extent (not application) is not
    # a determination: the law's application clause is needed (LAT parse).
    application_unknown = kind == :territorial and not determined?(law_basis, ctx)

    evidence = %{
      "kind" => Atom.to_string(kind),
      "source" => "changes",
      "applied" => applied?,
      "with_savings" => savings?,
      "revoked_regions" => revoked_regions,
      "remaining_regions" => remaining,
      "extent_gap" => extent_gap,
      "law_regions" => law_regions,
      "law_regions_basis" => law_basis,
      "application_unknown" => application_unknown,
      "text_repealed" => text_repealed?,
      "revokers" =>
        Enum.map(entries, fn {r, regs, basis} ->
          %{
            "by" => r.by,
            "affect" => r.affect,
            "target" => r.target,
            "applied" => r.applied,
            "revoker_made_date" => date_string(get_in(revokers, [r.by, :date])),
            "regions" => regs,
            "basis" => basis
          }
        end)
    }

    %Decision{
      live: if(kind == :territorial, do: @live_part_revoked, else: @live_revoked),
      kind: kind,
      description: describe(kind, by, revoked_regions, remaining, savings?),
      evidence: evidence
    }
  end

  defp revoker_regions(r, revokers, trust?) do
    marker = marker_regions(normalise(r.affect))
    type = r.by |> String.split("_") |> Enum.at(1)
    recorded = revokers |> Map.get(r.by, %{}) |> Map.get(:extent) |> regions()

    application = regions(r[:territorial_application])
    effect = regions(r[:effect_extent])

    cond do
      marker -> {marker, "affect_marker"}
      same_as_affected?(r[:effect_extent]) -> {@all_regions, "same_as_affected"}
      application -> {application, "territorial_application"}
      effect -> {effect, "effect_extent"}
      Map.has_key?(@devolved, type) -> {@devolved[type], "devolved_revoker"}
      recorded && trust? -> {recorded, "revoker_extent"}
      recorded -> {@all_regions, "uk_level_revoker"}
      true -> {@all_regions, "assumed_uk"}
    end
  end

  defp marker_regions(affect) do
    case Regex.run(@extent_marker, affect) do
      [_, m] ->
        m
        |> String.replace(~r/n\.?\s?i/, "NI")
        |> String.upcase()
        |> String.replace(~r/[\s.]/, "")
        |> String.split(~r/[+,]|(?<=[EWS])(?=[EWSN])/, trim: true)
        |> Enum.filter(&(&1 in @all_regions))
        |> nil_if_empty()

      _ ->
        nil
    end
  end

  # An SI cannot reach beyond its enabling Act(s): cap extent-based regions by
  # the parents' (sourced) extent. A bound that narrows is recorded ("+parent")
  # but is not itself a determination (`determined?/2`).
  defp bound_by_parents({regions, basis}, [_ | _] = parents)
       when basis in ["affected_extent", "extent"] and is_list(regions) do
    case sort_regions(Enum.filter(regions, &(&1 in parents))) do
      [] -> {regions, basis}
      ^regions -> {regions, basis}
      bounded -> {bounded, basis <> "+parent"}
    end
  end

  defp bound_by_parents(law_regions, _parents), do: law_regions

  # Where the law applies is determined by its type, title or application; on
  # extent only once its text has been read with no application clause (it
  # then applies throughout its extent) and that extent has a source —
  # legislation.gov.uk's effects or a law-level / LAT source. The enabling
  # Act's extent narrows but never determines: it is the union of all its
  # provisions (the Water Resources Act 1991 is GB; its powers are E+W).
  defp determined?(basis, _ctx) when basis in ["devolved_type", "title", "application"], do: true

  defp determined?(basis, ctx) do
    ctx[:law_clause_read] == true and
      (String.starts_with?(basis || "", "affected_extent") or
         ctx[:law_extent_source] not in [nil, ""])
  end

  # Where the law applies: a devolved type (a WSI's E+W legal extent applies to
  # Wales only); else the last jurisdiction in the title ("… (Wales) Order",
  # "(England and Scotland)"); else its application (own application clause,
  # or fractalaw's text/title application); else the AffectedExtent
  # legislation.gov.uk records on its whole-instrument effects; else its
  # recorded extent. The last two are extent, not application.
  # legislation.gov.uk's "SAME AS AFFECTED" effect extent (spelt with "+"
  # between the letters): the change reaches wherever the law does.
  defp same_as_affected?(nil), do: false

  defp same_as_affected?(e),
    do: e |> String.upcase() |> String.replace(~r/[\s.+]/, "") == "SAMEASAFFECTED"

  defp law_regions(type, title, application, affected, extent) do
    cond do
      r = Map.get(@devolved, type) -> {r, "devolved_type"}
      r = title_regions(title) -> {r, "title"}
      r = application && nil_if_empty(sort_regions(application)) -> {r, "application"}
      r = affected && nil_if_empty(sort_regions(affected)) -> {r, "affected_extent"}
      r = regions(extent) -> {r, "extent"}
      true -> {nil, nil}
    end
  end

  @nation "england|wales|scotland|northern ireland|great britain"
  @title_jurisdiction ~r/\(((?:#{@nation})(?:(?:,\s*|\s+and\s+)(?:#{@nation}))*)\)/i
  @nation_regions %{
    "england" => ~w(E),
    "wales" => ~w(W),
    "scotland" => ~w(S),
    "northern ireland" => ~w(NI),
    "great britain" => ~w(E W S)
  }

  defp title_regions(nil), do: nil

  defp title_regions(title) do
    case Regex.scan(@title_jurisdiction, title) do
      [] ->
        nil

      matches ->
        [_, last] = List.last(matches)

        last
        |> String.downcase()
        |> String.split(~r/,\s*|\s+and\s+/)
        |> Enum.flat_map(&Map.get(@nation_regions, &1, []))
        |> sort_regions()
    end
  end

  defp describe(:territorial, _by, revoked, remaining, _savings),
    do: "Revoked in #{Enum.join(revoked || [], "+")}; in force in #{Enum.join(remaining, "+")}"

  defp describe(kind, by, _revoked, _remaining, savings?) do
    who =
      case by do
        [one] -> one
        [first | rest] -> "#{first} and #{length(rest)} other#{if length(rest) > 1, do: "s"}"
      end

    "Revoked by #{who}" <>
      if(savings?, do: ", with savings", else: "") <>
      if(kind == :revoked_unapplied, do: " (not yet applied to the text)", else: "")
  end

  defp simple(kind, live, desc),
    do: %Decision{
      live: live,
      kind: kind,
      description: desc,
      evidence: %{"kind" => Atom.to_string(kind), "source" => "changes"}
    }

  # "Yes", or applied to the English text while the Welsh is pending.
  defp applied?(applied) do
    a = normalise(applied)
    a == "yes" or String.contains?(a, "applied to english")
  end

  defp commencement?(a), do: Regex.match?(~r/\bappointed day/, a)

  defp normalise(nil), do: ""
  defp normalise(s), do: s |> String.downcase() |> String.replace(~r/\s+/, " ") |> String.trim()

  defp sort_regions(regs), do: Enum.filter(@all_regions, &(&1 in regs))

  defp nil_if_empty([]), do: nil
  defp nil_if_empty(l), do: l

  defp date_string(nil), do: nil
  defp date_string(%Date{} = d), do: Date.to_iso8601(d)
  defp date_string(d), do: to_string(d)
end
