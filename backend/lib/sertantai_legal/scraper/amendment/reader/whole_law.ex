defmodule SertantaiLegal.Scraper.Amendment.Reader.WholeLaw do
  @moduledoc """
  An instruction revoking or repealing a whole law it names ("The Supply of
  Machinery (Safety) Regulations 2008 are revoked": SI 2026/867 reg.15(1);
  CV-S09 round 6) as one rule on the whole law (target `"*"`): the law's
  own text states the revocation the feed records, so its operation is
  primary. A provision named, or a list of laws ("The following … are
  revoked"), is not this form. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Text
  alias SertantaiLegal.Scraper.Amendment.Reader.LawNamed
  alias SertantaiLegal.Scraper.Amendment.Rule

  @whole ~r/^\W*(?:\(\w+\)\s*)?(?:Subject\s+to\s+[^,]+,\s*)?(?:the\s+)?(?<title>[^—:;]+?)\s+(?:is|are)\s+(?:hereby\s+)?(?<verb>revoked|repealed)\s*[.;]?\s*$/iu

  # a provision named (a number, never a title's year: "Regulations 2008"):
  # never the whole law
  @provision ~r/\b(?:sections?|regulations?|articles?|rules?|paragraphs?|Schedules?|Parts?|Chapters?)\s+\d{1,3}[A-Z]*\b|\bfollowing\b|\bin\s+so\s+far\b|\bto\s+the\s+extent\b/i

  @doc "The whole-law rule an instruction `text` states for one of `laws`; [] when not this form."
  @spec rules(Text.t(), map(), [map()], map()) :: [Rule.t()]
  def rules(%Text{instruction: i}, terms, laws, source) when is_binary(i) do
    with [_, title, _verb] <- Regex.run(@whole, i),
         false <- Regex.match?(@provision, title),
         [_ | _] = named <- LawNamed.named([i], terms) do
      for law <- laws,
          Enum.any?(named, &LawNamed.law_named?(&1, law)),
          do:
            Rule.new(
              amends: law.law_name,
              targets: ["*"],
              operation: :repealed,
              level: :provision,
              source: source,
              treatment: :instruction
            )
    else
      _ -> []
    end
  end

  def rules(_text, _terms, _laws, _source), do: []
end
