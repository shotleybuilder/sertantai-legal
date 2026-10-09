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
  7. no claim — for a removal, nothing names a territory: repealed
     everywhere, its text kept for savings or purposes (LR-07).

  Returns `{territory | nil, source | nil}` with source `:effect_application`,
  `:markup`, `:effect_in_force`, `:effect_not_in_force`, `:effect_extent` or
  `:effect_unreadable`. Notes are never read.
  Pure.
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect
  alias SertantaiLegal.Scraper.Territory

  @type source ::
          :effect_application
          | :markup
          | :effect_in_force
          | :effect_not_in_force
          | :effect_extent
          | :effect_unreadable

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
          String.t() | nil
        ) ::
          {String.t() | nil, source() | nil}
  def claim(effects, kind, attribute, row_extent \\ nil, provision \\ nil) do
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
      {:effect_unreadable, fn -> kind in [:keep, :pair] and territorial?(effects) and :none end}
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

  # "for E.", "for E.W.", "for S. so far as …"; not "for specified purposes"
  @for_territory ~r/\bfor ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)/

  @except_territory ~r/except in relation to ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)/

  # "for E." → E; "except in relation to W." → everywhere but W; a
  # qualifier scoped to provisions ("for S. for the repeal of ss. 1-19",
  # "for E. except in relation to ss. 13-15, 76") counts on the row's
  # provision when it is (or isn't) listed; purposes make it unusable
  defp in_force(effects, provision) do
    effects
    |> Enum.flat_map(& &1.in_force_qualifications)
    |> Enum.reject(&String.contains?(&1, "purpose"))
    |> Enum.flat_map(fn q ->
      except = Regex.run(@except_territory, q, capture: :all_but_first)

      case {except, territory_scope(q)} do
        {[territory], _} ->
          [Territory.subtract(nil, code(territory))]

        {nil, {territory, :all}} ->
          [code(territory)]

        {nil, {territory, scope}} ->
          if in_scope?(scope, provision), do: [code(territory)], else: []

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
    if String.contains?(qualification, "purpose"), do: nil, else: all_scope(qualification)
  end

  @doc """
  The territory an in-force qualification excludes when that is all it
  says ("except in relation to W.", give or take "in so far as not already
  in force"): W. Nil otherwise.
  """
  @spec except_territory(String.t()) :: String.t() | nil
  def except_territory(qualification) do
    case Regex.run(
           ~r/^except in relation to ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)\s*((in force )?(in )?so far as not already in force)?$/,
           String.trim(qualification),
           capture: :all_but_first
         ) do
      [territory | _] -> code(territory)
      nil -> nil
    end
  end

  defp all_scope(q) do
    case {Regex.run(@except_territory, q), territory_scope(q)} do
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
        Regex.run(@except_territory, q) == nil and
          match?({_, {_, _}}, territory_scope(q)) and
          scope_kind?(elem(territory_scope(q), 1), provision) and
          not in_scope?(elem(territory_scope(q), 1), provision)
      end)
  end

  # some qualifier names a territory
  defp territorial?(effects) do
    effects
    |> Enum.flat_map(& &1.in_force_qualifications)
    |> Enum.any?(&(Regex.match?(@for_territory, &1) or Regex.match?(@except_territory, &1)))
  end

  # "for E." alone, give or take a date note before it and "in so far as not
  # already in force" (or a timing) after it; anything more limits it to
  # part of the territory or the change ("for E. in relation to the pilot
  # areas": 2000/37; "for W. for the insertion of s. 53B") — unusable
  @before_territory ~r/^(\(being the da(te|y) on which .*came into force\)|at [\d.]+ [ap]\.m\.)?$/
  @after_territory ~r/^((in force )?(in )?so far as not already in force|to the extent, if any, that it is not already in force|immediately after the coming into force of .*)?$/

  @only_provisions ~r/^for the (?:repeal|revocation|omission|insertion|substitution) of (.+)$/
  @except_provisions ~r/^except in relation to (.+)$/

  # {territory, :all | {:only | :except, provisions}}; nil when unusable
  defp territory_scope(q) do
    with [{at, len}, {t_at, t_len}] <- Regex.run(@for_territory, q, return: :index),
         before = q |> binary_part(0, at) |> String.trim(),
         true <- before =~ @before_territory,
         rest = q |> binary_part(at + len, byte_size(q) - at - len) |> String.trim(),
         scope when scope != nil <- scope(rest) do
      {binary_part(q, t_at, t_len), scope}
    else
      _ -> nil
    end
  end

  defp scope(rest) do
    cond do
      rest =~ @after_territory -> :all
      m = Regex.run(@only_provisions, rest, capture: :all_but_first) -> provisions(:only, m)
      m = Regex.run(@except_provisions, rest, capture: :all_but_first) -> provisions(:except, m)
      true -> nil
    end
  end

  # "ss. 1-19, 22-28" / "s. 26(5)" / "regs. 3 and 4" → {mode, {kind, items}};
  # nil when any item can't be read
  @list ~r/^(ss?|regs?)\.\s+(.+?)\.?$/
  @item ~r/^(\d+[A-Z]*)(?:-(\d+[A-Z]*))?((?:\([0-9A-Za-z]+\))*)$/

  defp provisions(mode, [list]) do
    with [kind, items] <- Regex.run(@list, String.trim(list), capture: :all_but_first),
         items = String.split(items, ~r/,\s*|\s+and\s+/),
         parsed = Enum.map(items, &Regex.run(@item, String.trim(&1), capture: :all_but_first)),
         false <- Enum.any?(parsed, &is_nil/1) do
      {mode, {if(String.starts_with?(kind, "s"), do: "section", else: "regulation"), parsed}}
    else
      _ -> nil
    end
  end

  # the row's provision is of the scope's kind, so the list can be read for it
  defp scope_kind?(_scope, nil), do: false

  defp scope_kind?({_mode, {kind, _items}}, provision),
    do: String.starts_with?(provision, kind <> "-")

  # the row's provision ("section-14A-1") listed (or, for :except, not)
  defp in_scope?(_scope, nil), do: false

  defp in_scope?({mode, {kind, items}}, provision) do
    case Regex.run(~r/^(section|regulation)-(\d+[A-Z]*)((?:-[0-9A-Za-z]+)*)$/, provision,
           capture: :all_but_first
         ) do
      [^kind, number, path] ->
        listed = Enum.any?(items, &listed?(&1, number, path))
        if mode == :only, do: listed, else: not listed

      _ ->
        false
    end
  end

  defp listed?([from, to | _], number, _path) when to != "",
    do: number_key(from) <= number_key(number) and number_key(number) <= number_key(to)

  defp listed?([single | rest], number, path) do
    subs = rest |> List.last() |> to_string() |> then(&Regex.scan(~r/\(([0-9A-Za-z]+)\)/, &1))
    prefix = Enum.map_join(subs, fn [_, sub] -> "-" <> sub end)
    single == number and String.starts_with?(path, prefix)
  end

  defp number_key(number) do
    [digits, suffix] = Regex.run(~r/^(\d+)([A-Z]*)$/, number, capture: :all_but_first)
    {String.to_integer(digits), suffix}
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
