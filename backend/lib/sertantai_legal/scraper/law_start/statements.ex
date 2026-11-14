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
  @rest ~S"(?:(?:the|all)\s+)?(?:remaining|remainder|rest|other\s+provisions)\b"

  @break Regex.compile!(
           "(?:" <>
             ";\\s*(?:and\\s+)?(?=#{@numbered})" <>
             "|(?<=\\d{4})\\s+(?=#{@rest})" <>
             "|(?<=\\d{4})(?:\\s*,\\s*(?:and\\s+)?|\\s+and\\s+)(?=#{@numbered})" <>
             "|\\s*,\\s*and\\s+(?=#{@rest})" <>
             "|(?<=\\bappoint)\\s+and\\s+(?=#{@numbered}|#{@container})" <>
             ")(?=[^;]*\\binto\\s+(?:force|operation)\\b)",
           "i"
         )

  @doc "The statements of `sentence`, in order: the sentence itself when it is one."
  @spec split(String.t()) :: [String.t()]
  def split(sentence) do
    case Regex.split(@break, sentence) do
      [_one] = whole -> whole
      pieces -> if Enum.all?(pieces, &Regex.match?(@cif, &1)), do: pieces, else: [sentence]
    end
  end
end
