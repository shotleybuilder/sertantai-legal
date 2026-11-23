defmodule SertantaiLegal.Scraper.LawStart.Sentences do
  @moduledoc """
  A provision's text as sentences, and whether a sentence states a
  commencement or only mentions one. Pure. Its own module so the extent
  reader (and anything else splitting sentences) need not name the clause
  reader (`LawStart.Clause`, which delegates here), keeping it out of their
  version stamps (the Commencement reader staleness session).
  """

  # the first "comes into force" in a sentence, and what is before it (its
  # head) — a mention shows there: "before this section …", "the date on
  # which this section …", "the coming into force", "deemed to have …",
  # "If …", "… means …", "…, which came into force on …"; never a later
  # clause of a statement ("They come into force on the day after the day on
  # which they are made, save for regulation 10 which comes into force on 1st
  # October 2009": SI 2009/1581, CV-S04); a period named by it is a mention
  # too ("the quarter period within which these Regulations come into
  # force": SI 2025/910 reg.28(5)(b)(i))
  @first_cif ~r/\b(comes?|came|coming|be\s+brought|brought)\s+(?:fully\s+)?into\s+(?:force|operation)\b/i
  @mention_head ~r/\b(?:before|after|until|unless|when|whenever|once|since|if|by\s+the\s+time|on\s+or\s+after|immediately\s+before|(?:with)?in\s+which|(?:day|date|time)\s+(?:on|upon|at)\s+which|deemed\s+to\s+have|thereby|means)\b|\bthe\s*$|^\W*(?:\[[^\]]*:\s*)?(?:\(\w+\)\s*)?(?:where|when|if|until|unless|once)\b/i

  @doc """
  Whether a sentence only mentions a commencement ("before this section
  comes into force", "the date on which …", "the coming into force of",
  "which came into force on …") rather than stating one — read in its head,
  before its first "comes into force" (CV-S04).
  """
  @spec mention?(String.t()) :: boolean()
  def mention?(sentence) do
    case Regex.run(@first_cif, sentence, return: :index) do
      [{at, _}, {v, vlen}] ->
        head = binary_part(sentence, 0, at)
        verb = binary_part(sentence, v, vlen) |> String.downcase()

        Regex.match?(@mention_head, head) or
          verb == "coming" or
          head =~ ~r/\b(?:day|date|time)\s+(?:this|these|that|the|it|they)\b[^,;]{0,80}$/i or
          (verb == "came" and head =~ ~r/\bwhich\s*$/i) or
          (verb == "brought" and sentence =~ ~r/\bbrought\s+into\s+(?:force|operation)\s+by\b/i)

      _ ->
        false
    end
  end

  @doc """
  Whether a sentence states a commencement ("The following provisions come
  into force …"), not only mentions one (`mention?/1`): for other readers to
  leave it to the commencement ruleset (the extent reader's statements, CV-S05
  round 13).
  """
  @spec commences?(String.t()) :: boolean()
  def commences?(sentence), do: Regex.match?(@first_cif, sentence) and not mention?(sentence)

  @doc """
  A provision's text as sentences: a full stop then a capital or "(" — but
  not after an abbreviation ("Metrology etc. (Amendment etc.) (EU Exit)
  Regulations 2019 and come into force …": LR-43, SI 2019/696).
  """
  @spec sentences(String.t() | nil) :: [String.t()]
  def sentences(nil), do: []

  def sentences(text),
    do:
      text
      # (a no-break space is a space: "on 1st\u00A0January 2015", SI 2010/740
      # reg.1(2))
      |> String.replace(~r/\s+/u, " ")
      # a qualification set off by commas after "into force" is no staging:
      # "shall come into force, subject to the transitory provisions in …,
      # at the end of the period of six months …" (Road Traffic Act 1988 s.197(2))
      |> String.replace(~r/\binto (force|operation), subject to [^,]{1,250}, /i, "into \\1 ")
      |> String.split(
        ~r/(?<=\.)(?<!\betc\.)(?<!\bNo\.)(?<!\bNos\.)(?<!\bSch\.)(?<!\bart\.)(?<!\breg\.)(?<!\bs\.)(?<!\bc\.)(?<!\bi\.e\.)(?<!\be\.g\.)\s+(?=[A-Z(])/
      )
end
