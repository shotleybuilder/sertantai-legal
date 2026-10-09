defmodule SertantaiLegal.Scraper.LatDiffClass do
  @moduledoc """
  Classifies how a re-parse changes a LAT row, so a corpus diff is reviewed
  by pattern ("excluded_extent: nil → W" × 1,500 rows) rather than row by
  row (LAT Parser Refactor, LR-01).

  Handles:
  - `classify/2` — one class per changed field of a stored row vs a fresh
    parse (`text`, `title`, `excluded_extent`, `extent_code`), or
    `inserted` / `removed`
  - `unexpected/2` — the classes (with counts) no expected pattern matches

  Text classes: `whitespace` (only spacing differs), `brackets added` / `brackets removed` / `brackets changed`
  (the same words, territorial brackets differ), `reordered` (same words,
  see `LatTextDiff.kind/2`), else `words`.

  Pure: rows are maps with those four keys.
  """

  alias SertantaiLegal.Scraper.LatTextDiff

  @type row :: %{
          optional(:text) => String.t() | nil,
          optional(:title) => String.t() | nil,
          optional(:excluded_extent) => String.t() | nil,
          optional(:extent_code) => String.t() | nil
        }

  # "[E+W: " — a territorial bracket's opening
  @bracket_open ~r/\[((?:E|W|S|NI)(?:\+(?:E|W|S|NI))*): /u

  @doc "The classes of change from `old` to `new` (nil = no row), in field order."
  @spec classify(row() | nil, row() | nil) :: [String.t()]
  def classify(nil, nil), do: []
  def classify(nil, _new), do: ["inserted"]
  def classify(_old, nil), do: ["removed"]

  def classify(old, new) do
    [
      text_class(blank(old[:text]), blank(new[:text])),
      if(old[:title] != new[:title], do: "title: changed"),
      value_class("excluded_extent", old[:excluded_extent], new[:excluded_extent]),
      value_class("extent_code", old[:extent_code], new[:extent_code])
    ]
    |> Enum.reject(&is_nil/1)
  end

  @doc "The classes in `counts` (`%{class => n}`) that match none of `patterns`."
  @spec unexpected(%{String.t() => non_neg_integer()}, [Regex.t()]) :: %{
          String.t() => non_neg_integer()
        }
  def unexpected(counts, patterns) do
    Map.reject(counts, fn {class, _n} -> Enum.any?(patterns, &Regex.match?(&1, class)) end)
  end

  defp value_class(_field, same, same), do: nil
  defp value_class(field, old, new), do: "#{field}: #{old || "nil"} → #{new || "nil"}"

  defp text_class(same, same), do: nil

  defp text_class(old, new) do
    cond do
      squeeze(old) == squeeze(new) -> "text: whitespace"
      unbracketed(old) == unbracketed(new) -> "text: " <> bracket_change(old, new)
      LatTextDiff.kind(old, new) == "reordered" -> "text: reordered"
      true -> "text: words"
    end
  end

  defp bracket_change(old, new) do
    case {Regex.match?(@bracket_open, old), Regex.match?(@bracket_open, new)} do
      {false, true} -> "brackets added"
      {true, false} -> "brackets removed"
      _ -> "brackets changed"
    end
  end

  # The words without territorial brackets, whitespace normalised.
  defp unbracketed(text) do
    text
    |> String.replace(@bracket_open, "")
    |> String.replace("]", "")
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp squeeze(text), do: text |> String.replace(~r/\s+/u, " ") |> String.trim()

  defp blank(nil), do: ""
  defp blank(text), do: text
end
