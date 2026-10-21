defmodule SertantaiLegal.Scraper.EffectTerritory do
  @moduledoc """
  A change's territory from its effect and its markup (lat-refactor LR-03;
  plan `docs/LAT-EFFECTS-LAYER-PLAN.md`, decisions by Jason 2026-10-09).

  `claim/4` — in this order:
  1. the effect's territorial application — where the change applies;
  2. the markup `Extent`;
  3. for a change that removes text (`:keep`, `:pair`): the effect's
     in-force qualifications ("for S.") — gone where in force, kept
     elsewhere; purpose-limited qualifications don't count;
  4. for a removal not in force for this provision (prospective, or every
     in-force qualifier scoped to other provisions): none —
     `{nil, :effect_not_in_force}`; it removes nothing (LR-07);
  5. the effect's extent, only when narrower than the row's own extent
     (else the affected provision's) — a legal limit: a Scottish Act
     repeals only for S;
     never when wider or equal; "same as affected" is no territory;
  6. for a removal whose qualifiers name a territory that can't be read
     here: none — `{nil, :effect_unreadable}`; it removes nothing;
  6a. the affecting law's territory (`Effect.affecting_territory`,
     `LawTerritory`: a devolved type, the law's own title place, a
     register extent narrower than the UK), when every joined effect
     has one and it is narrower than the row's extent — a territorial law
     changes text only in its territory, whatever its savings (V1-04: SI
     2010/404 reg.14, repealed by the "(England)" SI 2023/911, stays in
     force in Wales) — removals only: retained text is legislation.gov.uk's
     sign that it still applies elsewhere; an insertion has no such sign,
     and a devolved law can insert text that applies across the border
     (Forestry Act 1967 s.1(1A), inserted by the Welsh SI 2013/755, defines
     the authority for England too); and only text the markup retains
     (`retained: false` for a whole-provision change from the effects
     layer: text legislation.gov.uk removed is repealed wholly, and a UK
     Act's repeal commonly "has the same extent as the provision
     repealed" — NERCA 2006 s.73);
  7. for a removal whose effect shows it reaches everywhere — in force for
     purposes only, with savings, or an effect extent covering the row's
     (1989/14 s.3(5): "Act repealed (S.)" on S rows): `{nil,
     :effect_everywhere}`, repealed everywhere, its text kept (LR-07);
  8. no claim — an effect silent on territory is not "everywhere"
     (1988/52 s.4(6): "repealed (E.W.)", no territory in the feed).

  Returns `{territory | nil, source | nil}` with source `:effect_application`,
  `:markup`, `:effect_in_force`, `:effect_not_in_force`, `:effect_extent`,
  `:effect_unreadable`, `:affecting_law` or `:effect_everywhere`. Notes are
  never read.
  Pure.
  """

  alias SertantaiLegal.Scraper.InForceQualifier, as: Qualifier
  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect
  alias SertantaiLegal.Scraper.Territory

  @type source ::
          :effect_application
          | :markup
          | :effect_in_force
          | :effect_not_in_force
          | :effect_extent
          | :effect_unreadable
          | :affecting_law
          | :effect_everywhere

  @doc """
  The territory of a change of `kind` with markup `attribute`, from its
  effect and that effect's parallels (`EffectIndex.parallel/2`: their
  territorial applications are unioned). A markup `Extent` disjoint from
  the application wins (a parallel change keyed to the wrong effect) and
  is reported (`conflict?/2`) — Jason 2026-10-09.
  """
  @spec claim(
          Effect.t() | [Effect.t()] | nil,
          :keep | :ins | :pair,
          String.t() | nil,
          String.t() | nil,
          String.t() | nil,
          keyword()
        ) ::
          {String.t() | nil, source() | nil}
  def claim(effects, kind, attribute, row_extent \\ nil, provision \\ nil, opts \\ []) do
    retained? = Keyword.get(opts, :retained, true)
    effects = effects |> List.wrap() |> Enum.reject(&is_nil/1)
    application = application(effects)
    markup = Territory.normalize(attribute)

    [
      {:markup,
       fn -> application && markup && Territory.disjoint?(application, markup) && markup end},
      {:effect_application, fn -> application end},
      {:markup, fn -> markup end},
      {:effect_in_force, fn -> kind in [:keep, :pair] and in_force(effects, provision) end},
      {:effect_not_in_force,
       fn -> kind in [:keep, :pair] and not_in_force?(effects, provision) and :none end},
      {:effect_extent, fn -> effects != [] and narrower_extent(hd(effects), row_extent) end},
      {:effect_unreadable, fn -> kind in [:keep, :pair] and territorial?(effects) and :none end},
      {:affecting_law,
       fn -> retained? and kind in [:keep, :pair] and affecting(effects, row_extent) end},
      {:effect_everywhere,
       fn -> kind in [:keep, :pair] and everywhere?(effects, row_extent) and :none end}
    ]
    |> Enum.find_value({nil, nil}, fn {source, value} ->
      case value.() do
        code when is_binary(code) -> {code, source}
        :none -> {nil, source}
        _ -> nil
      end
    end)
  end

  @doc "True when the markup Extent and the (unioned) territorial application share no territory."
  @spec conflict?(Effect.t() | [Effect.t()] | nil, String.t() | nil) :: boolean()
  def conflict?(effects, attribute) do
    with application when application != nil <-
           effects |> List.wrap() |> Enum.reject(&is_nil/1) |> application(),
         markup when markup != nil <- Territory.normalize(attribute) do
      Territory.disjoint?(application, markup)
    else
      _ -> false
    end
  end

  # the keyed effect's application, unioned with its parallels'; none when
  # the keyed effect names none (versions key their own effects: 2010/2214
  # reg.36[E] and [W])
  defp application([keyed | _] = effects) do
    if code(keyed.territorial_application) do
      effects
      |> Enum.map(&code(&1.territorial_application))
      |> Enum.reject(&is_nil/1)
      |> Territory.union()
    end
  end

  defp application([]), do: nil

  # "for E." → E; "except in relation to W." → everywhere but W; a
  # qualifier scoped to provisions ("for S. for the repeal of ss. 1-19",
  # "for E. except in relation to ss. 13-15, 76") counts on the row's
  # provision when it is (or isn't) listed; purposes make it unusable
  defp in_force(effects, provision) do
    effects
    |> Enum.flat_map(& &1.in_force_qualifications)
    |> Enum.reject(&Qualifier.purposes?/1)
    |> Enum.flat_map(fn q ->
      case {Qualifier.except(q), Qualifier.scope(q)} do
        {territory, _} when territory != nil ->
          [Territory.subtract(nil, code(territory))]

        {nil, {territory, :all}} ->
          [code(territory)]

        {nil, {territory, scope}} ->
          if Qualifier.in_scope?(scope, provision), do: [code(territory)], else: []

        {nil, nil} ->
          []
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      codes -> Territory.union(codes)
    end
  end

  @doc """
  The territory of an in-force qualification naming only a territory
  ("for E.", "for E.W. in so far as not already in force"); nil when it is
  scoped to provisions, limited to purposes or areas, or unreadable.
  """
  @spec qualifier_territory(String.t()) :: String.t() | nil
  def qualifier_territory(qualification) do
    if Qualifier.purposes?(qualification), do: nil, else: all_scope(qualification)
  end

  @doc """
  The territory an in-force qualification excludes when that is all it
  says ("except in relation to W.", give or take "in so far as not already
  in force"): W. Nil otherwise.
  """
  @spec except_territory(String.t()) :: String.t() | nil
  def except_territory(qualification), do: qualification |> Qualifier.only_except() |> code()

  defp all_scope(q) do
    case {Qualifier.except(q), Qualifier.scope(q)} do
      {nil, {territory, :all}} -> code(territory)
      _ -> nil
    end
  end

  # Not in force for this provision: the keyed effect is prospective, or
  # every qualifier is readable, names a territory and is scoped to other
  # provisions (1984/22 s.13: "for E. except in relation to ss. 13-15")
  # (an applied effect is in force: older effects carry an undated InForce
  # that reads as prospective — 24,921 of them)
  defp not_in_force?([%Effect{prospective: true, applied: applied} | _], _provision)
       when applied != true,
       do: true

  defp not_in_force?([], _provision), do: false

  defp not_in_force?(effects, provision) do
    qualifiers = Enum.flat_map(effects, & &1.in_force_qualifications)

    qualifiers != [] and
      Enum.all?(qualifiers, fn q ->
        Qualifier.except(q) == nil and
          match?({_, {_, _}}, Qualifier.scope(q)) and
          Qualifier.scope_kind?(elem(Qualifier.scope(q), 1), provision) and
          not Qualifier.in_scope?(elem(Qualifier.scope(q), 1), provision)
      end)
  end

  # the affecting laws' territory (the keyed effect's and its parallels'),
  # when each has one and it is narrower than the row's extent (else the
  # affected provision's: the law's own when the feed gives none)
  defp affecting([], _row_extent), do: nil

  defp affecting([keyed | _] = effects, row_extent) do
    codes = Enum.map(effects, & &1.affecting_territory)

    with false <- Enum.any?(codes, &is_nil/1),
         t = Territory.union(codes),
         false <- Territory.covers?(t, row_extent || code(keyed.affected_extent)) do
      t
    else
      _ -> nil
    end
  end

  # positive evidence a removal reaches the whole row: purposes, savings, or
  # an effect extent covering the row's
  defp everywhere?([], _row_extent), do: false

  defp everywhere?([keyed | _] = effects, row_extent) do
    qualifiers = Enum.flat_map(effects, & &1.in_force_qualifications)
    extent = code(keyed.effect_extent)

    # "revoked in part" of the whole instrument is never a full revocation,
    # whatever its extent, savings or purposes (Jason 2026-10-11; 2012/3038
    # "Regulations"); naming provisions, it repeals them wholly (1986/62
    # "s. 1-3": "in part" is about the instrument)
    not in_part?(keyed) and
      (Enum.any?(qualifiers, &Qualifier.purposes?/1) or
         Enum.any?(effects, &((&1.savings || []) != [])) or
         (extent != nil and row_extent != nil and Territory.covers?(extent, row_extent)))
  end

  defp in_part?(%Effect{type: type, affected_refs: refs}),
    do: refs in [nil, []] and String.match?(type || "", ~r/\bin part\b/i)

  # some qualifier names a territory
  defp territorial?(effects) do
    effects
    |> Enum.flat_map(& &1.in_force_qualifications)
    |> Enum.any?(&Qualifier.territorial?/1)
  end

  # narrower than the row's own extent when known (1986/62 s.21: an asp
  # repeal on an E+S row), else than the affected extent (the law's own
  # when the feed gives none)
  defp narrower_extent(%Effect{effect_extent: extent, affected_extent: affected}, row_extent) do
    with e when e != nil <- code(extent),
         false <- Territory.covers?(e, row_extent || code(affected)) do
      e
    else
      _ -> nil
    end
  end

  # an extent string as a code; nil for none or "same as affected"
  # (legislation.gov.uk's "S+A+M+E+A+S+A+F+F+E+C+T+E+D")
  defp code(nil), do: nil
  defp code("S+A+M+E" <> _), do: nil
  defp code(value), do: Territory.normalize(value)
end
