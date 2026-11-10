defmodule SertantaiLegal.Scraper.Amendment.Reader.Commencing do
  @moduledoc """
  A lead-in commencing the provisions listed under it ("the following
  regulations come into force on 1 June 2025—"): the amending-law reader
  skips its items, which name what an amendment inserts without changing
  anything (SSI 2025/165 reg.1(4), Environmental Protection: Amending-law
  reader, 2026-11-10). It reads no date: commencement is the commencement
  readers' (architecture test `CommencementReadTest`). Pure.
  """

  # a statement, never "the coming into force of this paragraph" (2021 c.30
  # Sch.12 para 14(5)) nor a definition's "the day when this section comes
  # into force, and …" (no closing dash: 2003 c.37 s.58)
  @lead_in ~r/\b(?:comes?|came)\s+into\s+(?:force|operation)\b[^.;]*[—–:]\s*$/iu

  @doc "Whether `text` is a lead-in commencing what is listed under it."
  @spec lead_in?(String.t()) :: boolean()
  def lead_in?(text), do: Regex.match?(@lead_in, text)
end
