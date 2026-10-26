defmodule SertantaiLegal.Scraper.AmendingLaw.SweepForm do
  @moduledoc """
  The form of a sentence the extent recall sweep found uncaught
  (`Extent.Sweep`; CV-S05a, reviewed with Jason 2026-10-26), so the count
  of what the extent reader misses is read by form, not by shape:

  - `read:*` — a statement of where provisions extend or apply that the
    reader is to read (CV-S05 round 7): `same_extent_of` ("The extent of
    any amendment … is the same as that of the enactment …"),
    `same_extent` ("has the same extent (in the United Kingdom / and
    application) as"), `exception` ("Subsection (1) does not apply to
    section 59(3), 90 …"), `also_there` ("The amendment … of any enactment
    extending to Northern Ireland also extends there"), `lettered` ("This
    Act extends only to— (a) …"), `application` (a provision's own
    application to a place: "Regulation 44 applies to Scotland only",
    "The following provisions apply in relation to England only— …";
    Jason: "read them as provision-level application");
  - `count:*` — stated, but not to be read into rules: `qualified` ("…
    extends— (a) to Scotland, so far as …", "Nothing in … affects the
    extent of …"), `outside_gb` (application outside Great Britain under
    the HSWA 1974 Order);
  - `noise:*` — no statement of the law's own territory: `commencement`,
    `outside_uk` (the Isle of Man, the Channel Islands, …), `instruction`
    (words of an amending instruction: "as it extends to", "substitute"),
    `modification` ("has effect in relation to Wales as if …"),
    `procedure` (definitions, powers, annulment, the Crown, territorial
    waters), `cases` (application to cases or persons, not places),
    `other`.

  Labels for review and counts only: the extent reading never depends on
  them. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Applies, Units}
  alias SertantaiLegal.Scraper.LawStart.Clause

  @places "England|Wales|Scotland|Northern Ireland|Great Britain|the United Kingdom|United Kingdom"
  @provisions "(?:Sections?|Subsections?|Regulations?|Articles?|Paragraphs?|Sub-paragraphs?|Parts?|Schedules?)"

  @rules [
    # (which regulations a procedure covers, not where: "Subsection (2) does
    # not apply to regulations which apply only in relation to England")
    {"noise:procedure", ~r/\bto\s+regulations\s+which\b/iu},
    # (an instruction's words run into the sentence: a statement inside it
    # can't be told from the words it inserts — ukpga 2005/15 Sch. 7 para 59)
    {"noise:instruction",
     ~r/\bas\s+(?:it|they)\s+(?:extends?|has\s+effect|have\s+effect|applies|apply)\b|\b(?:substitute|insert|omit)\b/iu},
    {"noise:outside_uk",
     ~r/Isle of Man|Channel Islands|Bailiwick|overseas territor|outside the United Kingdom|other jurisdiction|territory outside|Gibraltar|Isles of Scilly|\bextends?\s+outside\b/iu},
    {"count:outside_gb", ~r/\boutside\s+Great\s+Britain\b/iu},
    {"read:same_extent_of",
     ~r/\bthe\s+extent\s+of\s+(?:any|each|the|an?)\b.*\bis\s+the\s+same\b/iu},
    {"read:same_extent", ~r/\bsame\s+(?:territorial\s+)?(?:extent|application)\b/iu},
    {"count:qualified",
     ~r/\bextends?\s*[—–]|\b(?:limits?|affects?)\s+the\s+extent\b|\bso\s+far\s+as\b[^.]*\bextends?\s+to\s+any\s+place\b|\bextends?\s+to\s+any\s+place\b[^.]*\bso\s+far\s+as\b/iu},
    {"noise:modification",
     ~r/\bas\s+if\b|\bwith\s+the\s+(?:following\s+)?(?:substitution|modifications?)\b|\bsubject\s+to\s+the\s+modifications?\b/iu},
    # (never "a provision which extends there by virtue of subsection (5)":
    # a power-extension rider, ukpga 2014/22 s.76)
    {"read:also_there", ~r/\balso\s+extends?\s+(?:there|to\s+any\s+place)\b/iu},
    {"read:lettered", ~r/\bextends?\s+only\s+to\s*[—–]/iu},
    {"read:exception",
     ~r/^(?:But\s+)?(?:Subsection|Paragraph)s?\s+\(\w+\)(?:\s+and\s+\(\w+\))?\s+(?:does|do|shall)\s+not\s+apply\s+to\s*(?:[—–]|the\s+following|(?:sections?|regulations?|articles?|paragraphs?|Parts?|Schedules?)\s+[\d(]|the\s+(?:amendments?|repeals?|revocations?))/iu}
  ]

  # a provision's (or a list's, or an amendment's) application to a place
  @application [
    Regex.compile!(
      "^(?:(?:This|That)\\s+(?:paragraph|sub-paragraph|section|subsection|regulation|article|Part|Schedule)|#{@provisions}\\s+[\\d(]\\S*(?:(?:,|\\s+and|\\s+to)\\s+\\S+)*)[^.;]{0,60}?\\b(?:appl(?:y|ies)|ha(?:s|ve)\\s+effect|(?:does|do|shall)\\s+not\\s+apply|extends?\\s+and\\s+appl(?:y|ies))\\b[^.;]{0,30}\\b(?:#{@places})\\b",
      "iu"
    ),
    Regex.compile!(
      "^(?:The\\s+)?(?:following\\s+(?:provisions|regulations|articles|sections)|provisions\\s+in)\\b[^—–.]*\\b(?:appl(?:y|ies)|(?:do|does)\\s+not\\s+apply)\\b[^—–.]*\\b(?:#{@places})\\b",
      "iu"
    ),
    Regex.compile!(
      "^(?:(?:In\\s+Schedule\\s+\\d+\\S*\\s*[—–]\\s*\\w\\s+)?the\\s+)?(?:amendments?|omission|revocations?|repeals?)\\b[^.;]{0,120}\\bappl(?:y|ies)\\b[^.;]{0,40}\\b(?:#{@places})\\b",
      "iu"
    )
  ]

  @procedure ~r/Northern Ireland Act 1974|annulment|negative resolution|binds the Crown|\bmay by (?:regulations|order)\b|\bconsult|territorial (?:sea|waters)|seaward|\bmeans\b|\bconstrued\b|\bwith the consent\b|\bis subject to (?:subsection|paragraph|Schedule)/iu
  @cases ~r/\b(?:do|does|shall)\s+not\s+apply\s+(?:to|in\s+relation\s+to)\s+(?!section|regulation|article|paragraph|Part|Schedule|England|Wales|Scotland|Northern|Great|the\s+United)|\bappl(?:y|ies)\s+(?:to|in\s+the\s+case\s+of)\s*[—–]|\bapplies\s+(?:where|if)\b/iu

  @doc "The form of an uncaught sentence (see the moduledoc)."
  @spec form(String.t()) :: String.t()
  def form(s) do
    cond do
      # (commencement words read by their reader: `LawStart.Clause`)
      Clause.general?(s) or Clause.mention?(s) -> "noise:commencement"
      r = Enum.find(@rules, fn {_, rx} -> Regex.match?(rx, s) end) -> elem(r, 0)
      Enum.any?(@application, &Regex.match?(&1, s)) -> application(s)
      Regex.match?(@procedure, s) -> "noise:procedure"
      Regex.match?(@cases, s) -> "noise:cases"
      true -> "noise:other"
    end
  end

  # an application on a condition is qualified ("applies in Northern
  # Ireland where— …", "shall not apply in Scotland on Sundays …", "apply in
  # relation to Scotland as follows— …", "will continue to apply …")
  # (read only where the reader reads it whole: `Extent.Applies`)
  defp application(s) do
    cond do
      s =~ ~r/\b(?:where|if|unless|as\s+follows|continue|on\s+Sundays|so\s+far\s+as|insofar)\b/iu ->
        "count:qualified"

      s |> Units.statements() |> Enum.any?(&(Applies.statement(&1) != nil)) ->
        "read:application"

      true ->
        "count:qualified"
    end
  end

  @doc "The forms the extent reader is to read: an uncaught sentence in one is a miss."
  @spec read?(String.t()) :: boolean()
  def read?(form), do: String.starts_with?(form, "read:")
end
