defmodule SertantaiLegal.Scraper.LawStart.Eu do
  @moduledoc """
  EU law's start (lat-refactor LR-33 P3; `LawStart`'s EU treatments).

  - A directive (`eudr`) binds Member States: never in force in the UK
    itself, so `:eu_directive` (a known limit).
  - A regulation or decision: the EUR-Lex entry into force, when the
    EUR-Lex metadata legislation.gov.uk embeds is the original act's (CELEX
    `3…`). Where it is a consolidation's (CELEX `0…-YYYYMMDD`) its date is the
    consolidation's, so the date the act's own text states ("shall enter
    into force on 11 April 2007"); else `:eu_publication_relative` (the text
    counts from Official Journal publication, which we don't hold).

  Pure.
  """

  alias SertantaiLegal.Scraper.LawStart
  alias SertantaiLegal.Scraper.LawStart.Clause

  @doc "The start of an EU law from its CLML metadata and rows; nil for a non-EU type."
  @spec read(String.t(), String.t(), [map()]) :: LawStart.t() | nil
  def read("eudr", _head, _rows), do: %LawStart{treatment: :eu_directive, evidence: "type eudr"}

  def read(type, head, rows) when type in ~w(eur eudn) do
    original_act(head) || stated(rows) ||
      %LawStart{treatment: :eu_publication_relative, evidence: celex(head)}
  end

  def read(_type, _head, _rows), do: nil

  defp original_act(head) do
    with "3" <> _ = celex <- celex(head),
         [_, d] <-
           Regex.run(
             ~r"<RESOURCE_LEGAL_DATE_ENTRY-INTO-FORCE[^>]*>\s*<VALUE>(\d{4}-\d{2}-\d{2})</VALUE>",
             head
           ) do
      %LawStart{
        treatment: :eu_entry_into_force,
        date: Date.from_iso8601!(d),
        evidence: "eurlex:entry-into-force (CELEX #{celex})"
      }
    else
      _ -> nil
    end
  end

  defp celex(head) do
    case Regex.run(~r/<ukm:CELEX Value="([^"]+)"/, head) do
      [_, c] -> c
      nil -> nil
    end
  end

  # "This Regulation shall enter into force on 18 August 2005, except …"
  defp stated(rows) do
    Enum.find_value(rows, fn row ->
      with text when is_binary(text) <- row[:text],
           [_, tail] <- Regex.run(~r/\bshall enter into force\s+on\s+(.*)/is, text),
           %Date{} = d <- Clause.date_at_start(tail) do
        %LawStart{treatment: :eu_entry_into_force, date: d, evidence: row.section_id, text: text}
      else
        _ -> nil
      end
    end)
  end
end
