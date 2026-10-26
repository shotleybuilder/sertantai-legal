defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedAffecting do
  @moduledoc """
  The amending provisions a changes-feed effect names (its
  `affecting_provisions` text) as refs, named as our provisions are named
  (`Commencement.Order.ref`): "s. 29(4)" → "s.29(4)", "Sch. 7 para. 27(2)"
  → "sch.7.para.27(2)", and an article "art. 18" → "reg.18" (an Order's
  articles are `reg.` rows; CV-S05 round 7 NEW-6: SI 2022/1174 art. 18 was
  never found in its extent list). Pure.
  """

  @refs ~r/\b(?:Sch\.\s*(\d+[A-Z]*)(?:\s+Pt\.\s*(\d+[A-Z]*))?(?:\s+para\.\s*(\d+[A-Z]*(?:\([^)]+\))*))?|(s|reg|art)\.\s*(\d+[A-Z]*(?:\([^)]+\))*))/u

  @doc ~S"""
  Every provision named: "Sch. 7 para. 27(2) Sch. 17 Pt. 2" →
  ["sch.7.para.27(2)", "sch.17.pt.2"]; "s. 111, Sch. 7" → ["s.111", "sch.7"].
  """
  @spec refs(String.t() | nil) :: [String.t()]
  def refs(nil), do: []

  def refs(text) do
    @refs
    |> Regex.scan(text)
    |> Enum.map(fn
      [_, sch, "", ""] -> "sch.#{sch}"
      [_, sch, pt, ""] -> "sch.#{sch}.pt.#{pt}"
      [_, sch, "", para] -> "sch.#{sch}.para.#{para}"
      [_, sch, _pt, para] -> "sch.#{sch}.para.#{para}"
      [_, "", "", "", kind, n] -> "#{prefix(kind)}.#{n}"
      [_, sch] -> "sch.#{sch}"
      [_, sch, pt] -> "sch.#{sch}.pt.#{pt}"
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  @doc ~S"""
  The one provision named ("s. 47(1)" → "s.47(1)"; "Sch. 5 para. 3" →
  "sch.5.para.3"), nil for any other form.
  """
  @spec ref(String.t() | nil) :: String.t() | nil
  def ref(nil), do: nil

  def ref(text) do
    cond do
      m = Regex.run(~r/^\s*(s|reg|art)\.\s*(\d+[A-Z]*(?:\([^)]+\))*)\s*$/, text) ->
        [_, kind, rest] = m
        "#{prefix(kind)}.#{rest}"

      m = Regex.run(~r/^\s*Sch\.\s*(\d+[A-Z]*)\s+para\.\s*(\d+[A-Z]*(?:\([^)]+\))*)\s*$/, text) ->
        [_, sch, para] = m
        "sch.#{sch}.para.#{para}"

      true ->
        nil
    end
  end

  defp prefix("art"), do: "reg"
  defp prefix(kind), do: kind
end
