defmodule SertantaiLegal.Scraper.LawStart.Statements do
  @moduledoc """
  The commencement statements run together in one sentence, each with its
  own "into force":

  - after ";": "…, other than regulations 7 and 9 to 14, come into force on
    30th November 2018; regulations 7 and 9 to 14 come into force on 30th
    November 2019" (SI 2018/1107 reg.1(2));
  - after a date: "… on 31st December 2012 the remaining regulations come
    into force on …" (SI 2012/3152 reg.1(2)); "Regulations 6(3) and 7(1)
    and (2) shall come into force on 1st January 1990, regulations 5(4) …
    shall come into force on 1st January 1991 and regulation 8(3) shall
    come into force on 1st January 1996" (SI 1989/1401 reg.1(3));
  - ", and the remainder …": "Section forty-one of this Act shall come into
    operation on the passing of this Act, and the remainder of this Act
    shall come into operation on such day as …" (1962 c.58 s.70(3)); "…,
    and all other provisions of these Regulations shall come into force on
    1st April 2006" (SI 2006/641 reg.1);
  - a date, "and" and the rest: "This regulation and regulation 18(1) come
    into force on 30th June 2005 and all other regulations come into force
    on 1st August 2005" (SI 2005/1726 reg.1(2)); with the verb left out,
    the rest takes the verb of the statement before: "Parts I, II and V of
    these Regulations shall come into force on 11th July 1988, and the
    remainder on 1st October 1988" (SI 1988/1048 reg.1(2));
  - after "appoint": "Part I of this Act shall come into operation on such
    day as the Minister of Power may by order … appoint and Part II of this
    Act … shall come into operation on …" (1969 c.10 s.38(3)).

  A break only before a statement naming numbered provisions or the rest
  (never a list's next item or "; but otherwise …"), and only where every
  piece states a commencement; else the sentence is one statement. Pure.
  """

  @cif ~r/\b(?:shall\s+(?:,[^,]{0,160},\s*)?)?(?:comes?|came)\s+into\s+(?:force|operation)\b/i
  @numbered ~S"(?:regulations?|articles?|sections?|rules?)\s+\d"
  @container ~S"(?:Parts?|Chapters?)\s+[0-9IVXL]+\b"
  @rest ~S"(?:(?:the|all)\s+)?(?:remaining|remainder|rest|other\s+(?:provisions|regulations|articles|paragraphs|sections|rules))\b"

  @break Regex.compile!(
           "(?:" <>
             ";\\s*(?:and\\s+)?(?=#{@numbered})" <>
             "|(?<=\\d{4})\\s+(?:and\\s+)?(?=#{@rest})" <>
             "|(?<=\\d{4})(?:\\s*,\\s*(?:and\\s+)?|\\s+and\\s+)(?=#{@numbered})" <>
             "|\\s*,\\s*and\\s+(?=#{@rest})" <>
             "|(?<=\\bappoint)\\s+and\\s+(?=#{@numbered}|#{@container})" <>
             ")(?=[^;]*\\binto\\s+(?:force|operation)\\b)",
           "i"
         )

  # the rest with its verb left out, after a dated statement: the verb is
  # the one before (group 1), put back so the rest is a statement of its own
  @verbless Regex.compile!(
              "(\\b(?:shall\\s+)?(?:comes?|came)\\s+into\\s+(?:force|operation))" <>
                "(\\s+on\\s+[^,;]{0,40}?\\d{4}\\s*,?\\s+and\\s+" <>
                "(?:the\\s+)?(?:remainder|rest)(?:\\s+of\\s+(?:these|this)\\s+\\w+)?)" <>
                "(?=\\s+on\\s+\\d)",
              "i"
            )

  @doc "The statements of `sentence`, in order: the sentence itself when it is one."
  @spec split(String.t()) :: [String.t()]
  def split(sentence) do
    case Regex.split(@break, with_verb(sentence)) do
      [_one] -> [sentence]
      pieces -> if Enum.all?(pieces, &Regex.match?(@cif, &1)), do: pieces, else: [sentence]
    end
  end

  defp with_verb(sentence), do: Regex.replace(@verbless, sentence, "\\1\\2 \\1", global: false)
end
