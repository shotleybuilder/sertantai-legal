defmodule SertantaiLegal.Scraper.EffectTerritory do
  @moduledoc """
  A change's territory from its effect and its markup (lat-refactor LR-03;
  plan `docs/LAT-EFFECTS-LAYER-PLAN.md`, decisions by Jason 2026-10-09).

  `claim/3` — in this order:
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

  @doc "The territory of a change of `kind` with markup `attribute`, from its effect."
  @spec claim(Effect.t() | nil, :keep | :ins | :pair, String.t() | nil, String.t() | nil) ::
          {String.t() | nil, source() | nil}
  def claim(effect, kind, attribute, row_extent \\ nil) do
    [
      {:effect_application, fn -> effect && code(effect.territorial_application) end},
      {:markup, fn -> Territory.normalize(attribute) end},
      {:effect_in_force, fn -> (kind in [:keep, :pair] and effect) && in_force(effect) end},
      {:effect_extent, fn -> effect && narrower_extent(effect, row_extent) end}
    ]
    |> Enum.find_value({nil, nil}, fn {source, value} ->
      case value.() do
        code when is_binary(code) -> {code, source}
        _ -> nil
      end
    end)
  end

  @doc "True when the markup Extent and the effect's territorial application share no territory."
  @spec conflict?(Effect.t() | nil, String.t() | nil) :: boolean()
  def conflict?(effect, attribute) do
    with %Effect{} <- effect,
         ta when ta != nil <- code(effect.territorial_application),
         attr when attr != nil <- Territory.normalize(attribute) do
      Territory.disjoint?(ta, attr)
    else
      _ -> false
    end
  end

  # "for E.", "for E.W.", "for S. so far as …"; not "for specified purposes"
  @for_territory ~r/\bfor ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)/

  @except_territory ~r/except in relation to ((?:(?:[EWS]\.|N\.I\.?)(?:,?\s*(?:and\s+)?)?)+)/

  # "for E." → E; "except in relation to W." → everywhere but W; purposes,
  # or an except-clause naming provisions ("except in relation to ss.
  # 13-15"), make a qualifier unusable
  defp in_force(%Effect{in_force_qualifications: qualifications}) do
    qualifications
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
