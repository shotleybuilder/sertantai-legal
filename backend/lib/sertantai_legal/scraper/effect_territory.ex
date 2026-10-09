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
  4. the effect's extent, only when narrower than the row's own extent
     (else the affected provision's) — a legal limit: a Scottish Act
     repeals only for S;
     never when wider or equal; "same as affected" is no territory;
  5. no claim.

  Returns `{territory | nil, source | nil}` with source `:effect_application`,
  `:markup`, `:effect_in_force` or `:effect_extent`. Notes are never read.
  Pure.
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.ChangesFeed.Effect
  alias SertantaiLegal.Scraper.Territory

  @type source :: :effect_application | :markup | :effect_in_force | :effect_extent

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
          String.t() | nil
        ) ::
          {String.t() | nil, source() | nil}
  def claim(effects, kind, attribute, row_extent \\ nil) do
    effects = effects |> List.wrap() |> Enum.reject(&is_nil/1)
    application = application(effects)
    markup = Territory.normalize(attribute)

    [
      {:markup,
       fn -> application && markup && Territory.disjoint?(application, markup) && markup end},
      {:effect_application, fn -> application end},
      {:markup, fn -> markup end},
      {:effect_in_force, fn -> kind in [:keep, :pair] and in_force(effects) end},
      {:effect_extent, fn -> effects != [] and narrower_extent(hd(effects), row_extent) end}
    ]
    |> Enum.find_value({nil, nil}, fn {source, value} ->
      case value.() do
        code when is_binary(code) -> {code, source}
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

  defp application(effects) do
    case effects |> Enum.map(&code(&1.territorial_application)) |> Enum.reject(&is_nil/1) do
      [] -> nil
      codes -> Territory.union(codes)
    end
  end

  # "for E.", "for E.W.", "for S. so far as …"; not "for specified purposes"
  @for_territory ~r/\bfor ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)/

  @except_territory ~r/except in relation to ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)/

  # "for E." → E; "except in relation to W." → everywhere but W; purposes,
  # or an except-clause naming provisions ("except in relation to ss.
  # 13-15"), make a qualifier unusable
  defp in_force(effects) do
    effects
    |> Enum.flat_map(& &1.in_force_qualifications)
    |> Enum.reject(&String.contains?(&1, "purpose"))
    |> Enum.flat_map(fn q ->
      except = Regex.run(@except_territory, q, capture: :all_but_first)

      cond do
        except -> [Territory.subtract(nil, code(hd(except)))]
        String.contains?(q, "except") -> []
        match = Regex.run(@for_territory, q, capture: :all_but_first) -> [code(hd(match))]
        true -> []
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> case do
      [] -> nil
      codes -> Territory.union(codes)
    end
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
