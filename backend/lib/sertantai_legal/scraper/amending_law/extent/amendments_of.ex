defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.AmendmentsOf do
  @moduledoc """
  "This Act, so far as it gives effect to amendments of [laws], extends to
  …" made a target statement (`Extent.Targeted`): the changes to the laws
  named, by the law amended (Water Consolidation (Consequential Provisions)
  Act 1991 s.4(5)–(7); Waste, Water and Climate: Extent reader, Decision 2,
  2026-11-26):

  - "This Act so far as it gives effect to amendments of the Environmental
    Protection Act 1990 extends to Great Britain." → "The amendments of the
    Environmental Protection Act 1990 extend to Great Britain.";
  - "This Act, so far as it gives effect to amendments of the following
    enactments, that is to say— (a) …; and (c) …, extends to the whole
    United Kingdom." → "The amendments of the following enactments extend
    to the whole United Kingdom— (a) …; and (c) ….";
  - "… to the amendments in Schedule 1 to this Act of the following
    enactments …" → "The amendments of the following enactments in Schedule
    1 extend …": that Schedule's.

  Pure.
  """

  @lead "^\\s*(?:\\d+[A-Z]*\\s*)?This\\s+Act\\s*,?\\s+so\\s+far\\s+as\\s+it\\s+gives\\s+effect\\s+to\\s+(?:the\\s+)?amendments\\s+(?:in\\s+Schedule\\s+(?<sch>\\d+[A-Z]*)\\s+to\\s+this\\s+Act\\s+)?of\\s+"

  @list Regex.compile!(
          @lead <>
            "the\\s+following\\s+enactments\\s*,?\\s*(?:that\\s+is\\s+to\\s+say\\s*)?[—–]\\s*(?<list>.+?)\\s*,\\s*(?<verb>extends?\\s+.+?)\\s*\\.?\\s*$",
          "su"
        )

  @one Regex.compile!(
         @lead <>
           "(?<law>the\\s+[A-Z][^,]*?\\s(?:Act|Order|Regulations)(?:\\s+\\(Northern\\s+Ireland\\))?\\s+\\d{4})\\s*,?\\s+(?<verb>extends?\\s+.+?)\\s*\\.?\\s*$",
         "su"
       )

  @doc "The text made a target statement where it gives effect to amendments of laws named."
  @spec resolve(String.t()) :: String.t()
  def resolve(text) do
    cond do
      m = Regex.named_captures(@list, text) ->
        "The amendments of the following enactments#{in_schedule(m)} #{plural(m["verb"])}— #{m["list"]}."

      m = Regex.named_captures(@one, text) ->
        "The amendments of #{m["law"]} #{plural(m["verb"])}."

      true ->
        text
    end
  end

  defp in_schedule(%{"sch" => ""}), do: ""
  defp in_schedule(%{"sch" => n}), do: " in Schedule #{n}"

  # ("to the whole United Kingdom": a target statement names the place)
  defp plural(verb) do
    verb
    |> String.replace(~r/^extends\b/u, "extend")
    |> String.replace(~r/\bto\s+the\s+whole\s+(?:of\s+)?(?:the\s+)?/u, "to the ")
  end
end
