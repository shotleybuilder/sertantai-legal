defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.ScopeKind do
  @moduledoc """
  An "apply" statement's kind (Jason 2026-10-27, skill class KA):
  territorial (the place is what is said: "apply in relation to Wales"),
  scope (which things, persons or conditions, not where: "applies if …",
  "apply to United Kingdom ships", "outside Great Britain"), or both (a
  place bound with a scope: "apply to lessors of social homes in
  England"); nil for an extend statement (`census.py`'s `scope_kind`,
  `DIRECT`, `THING_CARVE`, `CARVE`; #192).
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.{Places, Re}

  @place_words "(?:England|Wales|Scotland|Northern\\s+Ireland|Great\\s+Britain|(?:the\\s+)?United\\s+Kingdom)"
  @direct Regex.compile!(
            "^\\s*(?:only\\s+)?(?:(?:to\\s+and\\s+)?(?:in\\s+relation\\s+to|to|in|as\\s+respects|within)\\s*)?(?:only\\s+)?(?:[—–:]\\s*\\(?[a-z]\\)?\\s*)?(?:the\\s+whole\\s+of\\s+)?(?:the\\s+sea\\s+adjacent\\s+to\\s+)?(?:the\\s+)?#{@place_words}\\b(?!\\s+(?:ships?|vessels?|fishing|aeroplanes?|aircraft|licen[cs]es?|nationals?|citizens?|companies|registered)\\b)",
            "iu"
          )
  @thing_carve ~r/\b(?:other\s+than|except|excluding|apart\s+from)\b(?!\s*(?:for\s+)?(?:as\b|this\b|that\b|in\s|where\b|so\b|(?:the\s+)?(?:regulations?|articles?|sections?|paragraphs?|sub-paragraphs?|Parts?|Schedules?|Chapters?|rules?|subsections?|provisions?)\b))/iu
  @carve ~r/\b(?:other\s+than|except|excluding|apart\s+from|unless)\b/iu
  @apply_verb ~r/\b(?:do(?:es)?\s+not\s+|shall\s+(?:not\s+)?|only\s+)?appl(?:y|ies)\b/iu
  @outside Regex.compile!("\\boutside\\s+(?:the\\s+)?#{@place_words}", "iu")
  @in_place Regex.compile!("\\bin\\s+(?:relation\\s+to\\s+)?(?:the\\s+)?#{@place_words}", "iu")
  @things ~r/\b(?:buildings?|persons?|premises|ships?|vessels?|undertakers?|land)\b/iu

  @doc "`THING_CARVE`: a carve-out of things, not provisions (\"other than an excepted energy building\")."
  @spec thing_carve() :: Regex.t()
  def thing_carve, do: @thing_carve

  @doc "`CARVE`: any carve-out word."
  @spec carve() :: Regex.t()
  def carve, do: @carve

  @doc "The segment's kind: \"territorial\", \"scope\", \"both\", or nil."
  @spec kind(map()) :: String.t() | nil
  def kind(seg) do
    v = Re.search(@apply_verb, seg.text)

    cond do
      seg.same or Regex.match?(~r/\bextends?\b/iu, seg.text) -> nil
      v == nil or seg.places == nil -> nil
      Map.get(seg, :inherited) -> inherited(seg.text)
      true -> after_verb(Re.from(seg.text, Re.stop(v)), seg)
    end
  end

  defp inherited(own_words) do
    if Places.code(own_words) != nil and not Re.match?(@direct, own_words) and
         Regex.match?(@things, own_words),
       do: "scope",
       else: "territorial"
  end

  defp after_verb(after_v, seg) do
    cond do
      Re.match?(~r/^\s*(?:only\s+)?(?:if|where|when|unless)\b/iu, after_v) ->
        "scope"

      Re.match?(@direct, after_v) ->
        if Regex.match?(@thing_carve, after_v), do: "scope", else: "territorial"

      Regex.match?(@outside, after_v) or seg.neg or Regex.match?(@thing_carve, after_v) ->
        "scope"

      # the place names no where ("United Kingdom ships")
      not Regex.match?(@in_place, after_v) ->
        "scope"

      true ->
        "both"
    end
  end
end
