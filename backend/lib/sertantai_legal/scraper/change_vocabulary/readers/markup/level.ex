defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.Level do
  @moduledoc """
  A markup change's level — words or the whole provision — and how sure the
  markup is of it (CV-S08 round 3):

  - **whole, sure** (`:level` `:provision`): the change wraps the
    provision's number; or the provision's text is gone and the change
    removed or inserted it (a RetainText Repeal round the text: 1988/52
    s.4(6); an EU Article repealed with its Title wrapped, its text dots:
    Directive 2002/44 Art 12; an EU point inserted and later omitted:
    REACH Art 3(43)).
  - **whole, by its text alone** (`:level_covering` `:provision`): the
    change covers all of the provision's words, its number outside. That
    is a whole provision or its words replaced, both ways in round 3 (Art
    7(8) "For paragraph 8 substitute"; reg.3(3)(e) "for the reference …
    substituted a reference"), so the evidence table ranks it below the
    feed (`Evidence`).
  - **words, sure** (`:level` `:words`): the change sits in part of the
    text.

  `heading_wrappers/1`: a provision substituted whole whose heading
  carries its own ChangeId under the same effect (SI 2009/1348 regs 19,
  20, 24): the heading's record claims no level of its own. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Claim

  @doc "The level claims for a change's occurrences on `target` (`ctx.own`: each row's own text)."
  @spec claims([map()], String.t(), map(), String.t()) :: [Claim.t()]
  def claims(occ, target, ctx, change_id) do
    own = Map.get(ctx.own, target)

    cond do
      sure_whole?(occ, target, own) ->
        Claim.new(:markup, :level, :provision, change_id)

      covers?(occ, own) or number_covered?(occ, target) ->
        Claim.new(:markup, :level_covering, :provision, change_id)

      true ->
        Claim.new(:markup, :level, :words, change_id)
    end
  end

  # (EU consolidation markup, "O…M…", opens its change before the number
  # whenever the replaced text starts the provision — REACH Art 77(2)(e)'s
  # first sentence, Art 14(4)'s introductory words, round 4 — so its
  # number is no sure sign: it covers)
  defp sure_whole?(occ, target, own) do
    (not eu?(hd(occ)) and
       Enum.any?(occ, &(&1.number? and (target == "*" or List.last(&1.path) == target)))) or
      (own == "" and
         (hd(occ).kind == :Repeal or
            (hd(occ).kind == :Addition and Enum.all?(occ, &(&1.text == "")))))
  end

  defp eu?(%{change_id: id}), do: id =~ ~r/^O\d+M\d+/

  # an EU change round the number covers the provision (below the feed)
  defp number_covered?(occ, target),
    do: eu?(hd(occ)) and Enum.any?(occ, &(&1.number? and List.last(&1.path) == target))

  @doc "True when the occurrences' text covers all of the row's own text (letters and digits)."
  @spec covers?([map()], String.t() | nil) :: boolean()
  def covers?(_occ, nil), do: false
  def covers?(_occ, ""), do: false

  def covers?(occ, own_text),
    do: String.contains?(occ |> Enum.map(& &1.text) |> Enum.join(), own_text)

  @doc "Claim sets with a heading wrapper's level dropped where its effect has another record on the row."
  @spec heading_wrappers([{String.t(), String.t(), [Claim.t()]}]) ::
          [{String.t(), String.t(), [Claim.t()]}]
  def heading_wrappers(sets) do
    bodies =
      for {key, ref, claims} <- sets,
          not heading?(claims),
          into: MapSet.new(),
          do: {key, ref}

    for {key, ref, claims} = set <- sets do
      if heading?(claims) and MapSet.member?(bodies, {key, ref}),
        do: {key, ref, Enum.reject(claims, &(&1.attribute in [:level, :level_covering]))},
        else: set
    end
  end

  defp heading?(claims), do: Enum.any?(claims, &(&1.attribute == :heading and &1.value == true))
end
