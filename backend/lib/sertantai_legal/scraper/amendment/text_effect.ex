defmodule SertantaiLegal.Scraper.Amendment.TextEffect do
  @moduledoc """
  Whether a feed effect is a text change the Amending-law reader reads (a
  substitution, insertion, repeal, renumbering or amendment; a commencement
  order's "coming into force" is the commencement pass's). Pure; apart from
  `Amendment.ReadLaw` so that the build and the read pass's choice of laws
  ask it without reaching the reading (the Amending-law reader stamps
  session, 2026-11-26).
  """

  alias SertantaiLegal.Scraper.EffectKind

  @text_kinds ~w(substituted inserted repealed renumbered amended)

  @doc "Whether a feed effect is a text change this reader reads."
  @spec text_effect?(%{type: String.t() | nil}) :: boolean()
  def text_effect?(%{type: type}), do: EffectKind.kind(type, nil) in @text_kinds
end
