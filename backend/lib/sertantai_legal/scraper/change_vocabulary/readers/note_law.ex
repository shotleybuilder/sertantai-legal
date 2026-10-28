defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.NoteLaw do
  @moduledoc """
  The law a note's words cite, where the note has no `Citation` link (CV-S07
  round 2): "… by The Health and Safety at Work etc. Act 1974 (Application
  outside Great Britain) Order 2004 (S.I. 2004/ 1822), art. 2" → 
  `UK_uksi_2004_1822`. A pointer for identity only (Jason 2026-10-28,
  `docs/CHANGE-IDENTITY-DESIGN.md` decision 3): the merge may use it to find
  the record's event, never as the change's `by`. Pure.
  """

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
