defmodule SertantaiLegal.Scraper.Amendment.Reader.EuDatedTitle do
  @moduledoc """
  An EU law named by its maker, kind, date and opening words, with no number
  ("Commission Decision of 19 February 2001 establishing the conditions for
  a derogation for glass packaging …", SI 2025/82 Sch.15 para.60; Amending-law
  reader: yield, 2026-11-27). The law's stored title begins with the same
  words and then carries what the amending text leaves out ("(notified under
  document number …)", "(2001/171/EC)"). Pure.
  """

  @lead ~r/\b(?:Commission|Council)(?:\s+(?:Implementing|Delegated))?\s+(?:Decision|Regulation|Directive)\s+of\s+\d{1,2}\s+[A-Z][a-z]+\s+\d{4}\b/u
  # the title runs to the instruction's words ("for “…”", "is amended")
  @stop ~r/\s+(?:for\s+[“"‘]|is\s+(?:further\s+)?amended\b|are\s+amended\b|after\s+[“"‘]|omit\b|insert\b|substitute\b)|[;—:]|\.(?:\s|$)/u
  # words after the date compared: enough to tell two Decisions of a day
  # apart, few enough to stop before a numeral written another way ("Annex
  # II" as "Annex 2")
  @words 8

  @doc "Each dated EU title in `text`: `{start, end, %{eu_dated: words}}`, by byte offset."
  @spec spans(String.t()) :: [{non_neg_integer(), non_neg_integer(), map()}]
  def spans(text) do
    for [{a, len}] <- Regex.scan(@lead, text, return: :index) do
      rest = binary_part(text, a + len, byte_size(text) - a - len)

      stop =
        case Regex.run(@stop, rest, return: :index) do
          [{s, _} | _] -> s
          nil -> byte_size(rest)
        end

      lead = binary_part(text, a, len)
      after_date = rest |> binary_part(0, stop) |> String.split() |> Enum.take(@words)
      {a, a + len + stop, %{eu_dated: Enum.join([lead | after_date], " ")}}
    end
  end

  @doc "`text` with each dated EU title blanked (its byte offsets kept)."
  @spec blank(String.t()) :: String.t()
  def blank(text) do
    text
    |> spans()
    |> Enum.reduce(text, fn {a, b, _}, t ->
      binary_part(t, 0, a) <> String.duplicate(" ", b - a) <> binary_part(t, b, byte_size(t) - b)
    end)
  end

  @doc "Whether the dated words `words` begin the EU law `law`'s title."
  @spec named?(String.t(), map()) :: boolean()
  def named?(words, %{law_name: "UK_eu" <> _, title: title}) when is_binary(title),
    do: String.starts_with?(norm(title), norm(words))

  def named?(_words, _law), do: false

  defp norm(t), do: t |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, " ") |> String.trim()
end
