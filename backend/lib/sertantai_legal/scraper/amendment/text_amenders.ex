defmodule SertantaiLegal.Scraper.Amendment.TextAmenders do
  @moduledoc """
  The amending laws of a law's text changes: its stored rules' sources
  (`amendment_rules`) and the amending laws its changes feed names on a
  text effect (`TextEffect`: a modification or a commencement is none).
  One definition for the build's stale reason (`Store.Inputs`,
  `:amending_reader`), the step's stale list (`StepProcedures.AmendingStale`)
  and the read pass's pointers (`ReadPass.feed_pointers/0`), so a read of
  every stale amending law clears the reason (the Amending-law reader step
  procedures session, 2026-11-26: the build counted modifications too, 122
  pairs on the round no read would clear). DB and stored feed reads.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.Amendment.TextEffect
  alias SertantaiLegal.Scraper.LatStagedParser

  @type effect :: %{type: String.t() | nil, affecting: String.t() | nil}

  @doc "The text effects of `law`'s stored changes feed whose amending law is a UK law."
  @spec feed_effects(String.t()) :: [map()]
  def feed_effects(law) do
    for e <- LatStagedParser.law_effects(law, store: :only) || [], text?(e), do: e
  end

  @doc "The amending laws of `effects`' text effects, in order, each once."
  @spec from_effects([effect()]) :: [String.t()]
  def from_effects(effects), do: for(e <- effects, text?(e), uniq: true, do: e.affecting)

  @doc "`law`'s text amenders."
  @spec of(String.t()) :: [String.t()]
  def of(law), do: [law] |> for_laws() |> Map.fetch!(law)

  @doc """
  Each of `laws`' text amenders, sorted; `effects` gives a law's feed
  effects (`feed_effects/1`, a stub in tests).
  """
  @spec for_laws([String.t()], (String.t() -> [effect()])) :: %{String.t() => [String.t()]}
  def for_laws(laws, effects \\ &feed_effects/1) do
    sources = rule_sources(laws)

    Map.new(laws, fn law ->
      feed = law |> effects.() |> from_effects()
      {law, (Map.get(sources, law, []) ++ feed) |> Enum.uniq() |> Enum.sort()}
    end)
  end

  defp text?(%{affecting: "UK_" <> _, type: type}), do: TextEffect.text_effect?(%{type: type})
  defp text?(_effect), do: false

  defp rule_sources(laws) do
    Repo.query!(
      "SELECT DISTINCT amends, source_law FROM amendment_rules WHERE amends = ANY($1) AND source_law ~ '^UK_'",
      [laws],
      timeout: :infinity
    ).rows
    |> Enum.group_by(&hd/1, &List.last/1)
  end
end
