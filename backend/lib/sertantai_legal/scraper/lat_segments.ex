defmodule SertantaiLegal.Scraper.LatSegments do
  @moduledoc """
  LAT row text as data (LAT Parser Refactor, LR-02): the parser builds each
  row's text as a list of segments, and `LatTerritory.render/4` turns it
  into the stored string once the row's extent is known. This replaces the
  private-use placeholder characters that carried territory through the
  text pipeline as a string.

  Segments:
  - `{:text, s}` — words of the provision
  - `{:mark, s}` — text the parser adds: list labels ("(a) "), table
    separators (" | ", "; "), the gap marker (" … "), quote marks («, »).
    Rendered as written; never counted as the row's own words when
    deciding a whole-row territory
  - `{:aside, segments}` — text shown but not the row's own words when
    deciding a whole-row territory: a quoted provision's number or title
    (numbers and titles never count)
  - `{:words, %LatTerritory.Change{}, segments}` — words a change wraps
    (retained repeal or territorial insertion)
  - `{:pair, %LatTerritory.Change{}, new, old}` — a substitution's two
    versions
  - `{:pair_old, sub_ref, change, segments}` / `{:pair_new, change_id,
    change, segments}` — halves of a substitution that are not siblings,
    joined by `LatTerritory.pair_up/1`

  Handles the generic list operations: `text/1`, `mark/1`, `join/2`,
  `blank?/1`, `plain/1`, `trim/1`, `append_in_quote/2`.
  """

  alias SertantaiLegal.Scraper.LatTerritory.Change

  @type segment ::
          {:text, String.t()}
          | {:mark, String.t()}
          | {:aside, t()}
          | {:words, Change.t(), t()}
          | {:pair, Change.t(), t(), t()}
          | {:pair_old, String.t(), Change.t(), t()}
          | {:pair_new, String.t(), Change.t(), t()}
  @type t :: [segment()]

  @doc "Provision words as segments; none for an empty string."
  @spec text(String.t() | nil) :: t()
  def text(s) when s in [nil, ""], do: []
  def text(s), do: [{:text, s}]

  @doc "Parser-added text (labels, separators, quote marks) as segments."
  @spec mark(String.t()) :: t()
  def mark(""), do: []
  def mark(s), do: [{:mark, s}]

  @doc "Shown, but never the row's own words (a quoted number or title)."
  @spec aside(t()) :: t()
  def aside([]), do: []
  def aside(segments), do: [{:aside, segments}]

  @doc "The non-blank parts, with `separator` (a mark) between them."
  @spec join([t()], String.t()) :: t()
  def join(parts, separator) do
    parts
    |> Enum.reject(&blank?/1)
    |> Enum.intersperse(mark(separator))
    |> Enum.concat()
  end

  @doc "True when the segments hold no visible character."
  @spec blank?(t()) :: boolean()
  def blank?(segments), do: segments |> plain() |> String.trim() == ""

  @doc """
  The words as written, territory ignored: a pair gives its new version,
  then its old one. For checks made before a row's extent is known (an
  open lead-in's closing dash).
  """
  @spec plain(t()) :: String.t()
  def plain(segments), do: Enum.map_join(segments, &plain_segment/1)

  defp plain_segment({kind, s}) when kind in [:text, :mark], do: s
  defp plain_segment({:aside, inner}), do: plain(inner)
  defp plain_segment({:words, _change, inner}), do: plain(inner)
  defp plain_segment({:pair, _change, new, old}), do: plain(new) <> " " <> plain(old)
  defp plain_segment({:pair_old, _ref, _change, inner}), do: plain(inner)
  defp plain_segment({:pair_new, _id, _change, inner}), do: plain(inner)

  @doc """
  Leading whitespace of the first visible segment and trailing of the last
  trimmed, reaching into a change or aside at the edge; blank edge segments
  dropped.
  """
  @spec trim(t()) :: t()
  def trim(segments) do
    segments
    |> trim_edge(:leading)
    |> Enum.reverse()
    |> trim_edge(:trailing)
    |> Enum.reverse()
  end

  # `segments` is in reading order for :leading, reversed for :trailing.
  defp trim_edge([{kind, s} | rest], side) when kind in [:text, :mark] do
    case trim_side(s, side) do
      "" -> trim_edge(rest, side)
      trimmed -> [{kind, trimmed} | rest]
    end
  end

  defp trim_edge([{:words, change, inner} | rest], side),
    do: trim_inner(inner, rest, side, &{:words, change, &1})

  defp trim_edge([{:aside, inner} | rest], side),
    do: trim_inner(inner, rest, side, &{:aside, &1})

  defp trim_edge(segments, _side), do: segments

  defp trim_inner(inner, rest, side, wrap) do
    case inner |> in_order(side) |> trim_edge(side) do
      [] -> trim_edge(rest, side)
      trimmed -> [wrap.(in_order(trimmed, side)) | rest]
    end
  end

  defp in_order(list, :leading), do: list
  defp in_order(list, :trailing), do: Enum.reverse(list)

  defp trim_side(s, :leading), do: String.trim_leading(s)
  defp trim_side(s, :trailing), do: String.trim_trailing(s)

  @doc """
  AppendText joins the block before it: inside a closing quote mark ("…and”.»"),
  else at its end.
  """
  @spec append_in_quote(t(), t()) :: t()
  def append_in_quote(segments, appended) do
    case Enum.reverse(segments) do
      [{:mark, "»"} | rest] -> Enum.reverse(rest, appended ++ mark("»"))
      _ -> segments ++ appended
    end
  end
end
