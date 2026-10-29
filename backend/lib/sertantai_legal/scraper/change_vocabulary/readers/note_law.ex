defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.NoteLaw do
  @moduledoc """
  The law a note's words cite, where the note has no `Citation` link (CV-S07
  round 2): "… by The Health and Safety at Work etc. Act 1974 (Application
  outside Great Britain) Order 2004 (S.I. 2004/ 1822), art. 2" → 
  `UK_uksi_2004_1822`. A pointer for identity only (Jason 2026-10-28,
  `docs/CHANGE-IDENTITY-DESIGN.md` decision 3): the merge may use it to find
  the record's event, never as the change's `by`. Pure.
  """

  @doc """
  A note's words as its identity, for the merge (CV-S07): the same note
  copied into each version of a provision carries its own id but these
  words. Lower case, spaces collapsed, its asides out — the savings "(with
  …)" and "(… SIF …)" differ between copies of one note (HSWA s.28(5)(b):
  "189(4)–(10)" and "189(4), (10)"). A 12-hex digest; nil for no words.
  """
  @spec digest(String.t() | nil) :: String.t() | nil
  def digest(nil), do: nil

  def digest(text) do
    normal =
      text
      |> asides_out()
      |> String.downcase()
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()

    if normal != "",
      do: :crypto.hash(:md5, normal) |> Base.encode16(case: :lower) |> binary_part(0, 12)
  end

  # "(with …)" and "(…SIF…)" with whatever brackets they hold
  defp asides_out(text) do
    case Regex.run(~r/\((?:with\b|[^()]*\bSIF\b)/u, text, return: :index) do
      [{at, _}] ->
        close = closing(text, at)
        asides_out(binary_part(text, 0, at) <> binary_part(text, close, byte_size(text) - close))

      nil ->
        text
    end
  end

  # the byte after the bracket opened at `at` closes (the end, unbalanced)
  defp closing(text, at) do
    text
    |> binary_part(at, byte_size(text) - at)
    |> String.graphemes()
    |> Enum.reduce_while({0, at}, fn g, {depth, pos} ->
      depth = depth + if(g == "(", do: 1, else: if(g == ")", do: -1, else: 0))
      pos = pos + byte_size(g)
      if depth == 0, do: {:halt, {0, pos}}, else: {:cont, {depth, pos}}
    end)
    |> elem(1)
  end

  # the instrument forms, the most specific first
  @forms [
    {~r/\bS\.\s*S\.\s*I\.\s*(\d{4})\s*\/\s*(\d+)/u, "ssi"},
    {~r/\bS\.\s*R\.\s*(\d{4})\s*\/\s*(\d+)/u, "nisr"},
    {~r/\bS\.\s*I\.\s*(\d{4})\s*\/\s*(\d+)/u, "uksi"},
    {~r/\b(\d{4})\s*\(\s*c\.\s*(\d+)\s*\)/u, "ukpga"}
  ]

  @doc "The first law the words cite, as a law name, or nil."
  @spec law(String.t() | nil) :: String.t() | nil
  def law(nil), do: nil

  def law(text) do
    @forms
    |> Enum.map(fn {re, type} -> {Regex.run(re, text, return: :index), re, type} end)
    |> Enum.filter(fn {at, _, _} -> at != nil end)
    |> Enum.min_by(fn {[{i, _} | _], _, _} -> i end, fn -> nil end)
    |> case do
      nil ->
        nil

      {_, re, type} ->
        [_, year, number] = Regex.run(re, text)
        "UK_#{type}_#{year}_#{number}"
    end
  end
end
