defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Forms do
  @moduledoc """
  The forms an extent clause's sentences take, as patterns (CV-S05;
  decomposed from `AmendingLaw.Extent`, run time 2026-10-25): the law
  speaking of itself (`subject/0`, a regex source string), its default
  ("This Act extends to …", "… does not extend to …"), list headings
  ("The following extend also to Scotland—"), provisions named ("Sections
  107 and 116A … extend to Scotland only"), and amendments having the
  enactment's extent. One function per form, named after it; each form's
  comment gives the real wording behind it. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Extent.Places

  @place_list Places.place_list()

  # the law speaking of itself (an Act, an SI; "The provisions of this
  # Order"), not of some provisions of it ("The following provisions of
  # this Act extend …" is a list)
  # (also "the preceding provisions of this Act (including the Schedules)":
  # 1998/8 s.16(1), CV-S05 N7)
  @subject "(?:\\bThe provisions of |\\bthe preceding provisions of |(?<!of )(?<!in )(?<!to )(?<!to, )\\b)(?:this Act|these Regulations|this Order|these Rules|this Scheme)(?:\\s*\\(including the Schedules?(?: to it)?\\))?"
  # (also "… of this Act, and no others, shall extend to Scotland—", "…
  # extend to Scotland, namely, Part III; …": CV-S05)
  # (several places: "… extend to England and Wales, Scotland and Northern
  # Ireland—"; "of these Regulations", "of this Order": CV-S05 N4, N11)
  # (also "The following provisions of Part II do not extend to Northern
  # Ireland— …": a `:not` list, CV-S05 A)
  @heading ~r/The following (?:provisions (?:of (?:this (?:Act|Part|Order)|these Regulations|Part [IVXLC\d]+[A-Z]*(?: of this Act)?) )?)?(?:,?\s*and no others,\s*)?(?:shall\s+)?(?:(?:also\s+)?extend(?:s)? (also )?to (#{@place_list})( only)?|(?:do|does|shall) not extend to (#{@place_list})|ha(?:s|ve) the same extent as the enactments? to which (?:it|they) relates?)(?:\s*[—–:-]|,?\s+(?:namely|that\s+is\s+to\s+say)\b[,:—–]?)/iu
  @extends Regex.compile!(
             # (", which subject to subsections (8) to (10) below extends to
             # Scotland only— (a) may be cited as …": the dash lists what the
             # Act does, 1995/36 s.105(1); never with exceptions after it:
             # "… with the exception of—", ", except …" — CV-S05 N6, N15)
             "#{@subject}(?:,\\s*which(?:\\s+subject\\s+to\\s+[^—–,]{1,80}?)?)?\\s+(?:shall\\s+)?extends?\\s+(?:(?:only\\s+)?to\\s+(?:the\\s+whole\\s+of\\s+)?|throughout\\s+)((?>#{@place_list}))(?:\\s+only)?(?!\\s*[—–](?!\\s*\\(?a\\)?\\s*may\\s+be\\s+cited))(?!\\s*,?\\s*(?:with\\s+the\\s+exception|except|save\\s+(?:as|that|for)|apart\\s+from|other\\s+than|excluding)\\b)",
             "iu"
           )
  # "The provisions of this Act extend to England and Wales and, except as
  # mentioned below, to Northern Ireland" (Arbitration Act 1996 s.108(1)):
  # both; the exceptions are stated below and read there (CV-S05 A)
  @extends_and Regex.compile!(
                 "#{@subject}\\s+(?:shall\\s+)?extends?\\s+to\\s+(?<a>(?>#{@place_list}))\\s+and\\s*,\\s*(?:except|save)\\s+as\\s+(?:otherwise\\s+)?(?:mentioned|provided|stated|specified)\\s+(?:below|above|in\\s+[^,]{1,80}),\\s*to\\s+(?<b>(?>#{@place_list}))",
                 "iu"
               )

  # the default with exceptions after it ("This Act extends to the whole of
  # the United Kingdom, except for Part 1, which extends to England and
  # Wales only"; "… except regulation 15"; "… except as otherwise provided
  # by subsections (2) to (6)"): read where the exceptions read plainly
  # (`exceptions/3`), else unread (CV-S05)
  @extends_exc Regex.compile!(
                 "#{@subject}(?:,\\s*which)?\\s+(?:shall\\s+)?extends?\\s+(?:to\\s+(?:the\\s+whole\\s+of\\s+)?|throughout\\s+)(?<places>(?>#{@place_list}))(?:\\s+only)?\\s*,?\\s*(?<exc>(?:except|save|apart\\s+from|other\\s+than|excluding)\\b[^.]*)",
                 "iu"
               )

  # "These Regulations— (a) may be cited as …; (b) come into force …; and
  # (c) extend to Scotland only" (a citation clause's list: CV-S05)
  @cited_list Regex.compile!(
                "#{@subject}\\s*[—–][^.]*?;\\s*(?:and\\s+)?(?:\\(?[a-z]\\)?\\s*)?(?:shall\\s+)?(?<not>do\\s+not\\s+|does\\s+not\\s+)?extends?\\s+to\\s+(?:the\\s+whole\\s+of\\s+)?(#{@place_list})",
                "iu"
              )
  # "Sections 107 and 116A of this Act extend to Scotland only", "Section 82
  # above (with Schedule 9) extends to Northern Ireland only", "Parts 2 and
  # 3 do not extend to Northern Ireland", "This Part of this Act shall
  # extend to Scotland and Northern Ireland": named provisions' own extent
  # (CV-S05)
  @named Regex.compile!(
           # (also articles, regulations, rules; "Subject to …, Parts 1 to 5
           # extend …"; "The amendments made by regulations 8 and 12 extend
           # …", "The modifications specified in paragraphs 65 … of Schedule
           # 2 extend …": CV-S05 N5, N8, N14)
           "^(?:\\(\\w+\\)\\s*)?(?:Subject\\s+to\\s+[^,—–]{1,120},\\s*)?(?<subj>(?:(?:The\\s+)?(?:amendments?|modifications?|repeals?|revocations?)\\s+(?:made\\s+by|specified\\s+in|in)\\s+)?(?:Sections?|Articles?|Regulations?|Rules?|Parts?|Schedules?|paragraphs?|This\\s+Part|This\\s+section|This\\s+regulation|This\\s+article)\\b(?:(?!\\bextends?\\b|\\bextend\\b).)*?)\\s+(?:shall\\s+)?(?<also>also\\s+)?(?<not>(?:do|does|shall)\\s+not\\s+)?extends?\\s+(?<only>only\\s+)?(?<also2>also\\s+)?(?:to\\s+(?:the\\s+whole\\s+of\\s+)?|throughout\\s+)(?<places>#{@place_list})(?<only2>\\s+only)?",
           "iu"
         )
  # "The amendments and repeals in Schedules 20 and 21 have the same extent
  # as the enactments to which they refer", "An amendment, repeal or
  # revocation made by this Order has the same extent as the provision to
  # which it relates": those provisions follow the enactment they change
  # (`:same`; "*" for every one the law makes) — CV-S05
  # (also "Except as provided by subsections (2) and (3), a repeal,
  # revocation or other amendment … has the same extent as …", "… the same
  # extent within the United Kingdom as …", "an amendment … extends to the
  # part or parts of the United Kingdom to which the enactment extends":
  # CV-S05 round 4 N-B)
  @amendments_same ~r/^(?:\(\w+\)\s*)?(?:(?:Subject\s+to|Except\s+as\s+(?:otherwise\s+)?(?:provided|set\s+out|specified|mentioned)\s+(?:by|in))[^,]*,\s*)?(?:An?|The|Any|Each)\s+(?:other\s+)?(?:amendments?|repeals?|revocations?|modifications?)(?:\s*,\s*|\s+(?:and|or)\s+)?(?:(?:other\s+)?(?:amendments?|repeals?|revocations?|modifications?)(?:\s*,\s*|\s+(?:and|or)\s+)?)*(?<subj>.*?)\s+(?:(?:has|have|shall\s+have)\s+the\s+same\s+(?:application\s+and\s+)?extent\s+(?:within\s+the\s+United\s+Kingdom\s+)?as\s+(?:that\s+of\s+)?|extends?\s+to\s+the\s+(?:same\s+)?part\s+or\s+parts\s+of\s+the\s+United\s+Kingdom\s+(?:as|to\s+which)\s+)the\s+(?:enactments?|provisions?|instruments?|legislation)\b(?!\s+as\s+if)/iu

  # "This Act shall extend to Northern Ireland with the exception of— (a)
  # the provisions of Part 1; (b) any provision amending … which does not so
  # extend; …" (CPA 1987 s.49(1)): an Act of the UK Parliament, so Great
  # Britain and that place; the Parts and provisions named, plainly, not
  # there (CV-S05 N15)
  @extends_except Regex.compile!(
                    "\\bThis\\s+Act\\s+(?:shall\\s+)?extends?\\s+to\\s+(?<places>#{@place_list})\\s+with\\s+the\\s+exception\\s+of\\s*[—–:]\\s*(?<list>[^.]*)",
                    "iu"
                  )

  # "Only the following provisions of this Act (together with this section)
  # extend to Northern Ireland, namely— section 3(5) to (8); …; Part V; …"
  # (EPA 1990 s.164): the rest of the UK is the default; the items not
  # qualified ("in so far as it relates to importation") also extend there
  @only_following Regex.compile!(
                    "\\bOnly\\s+the\\s+following\\s+provisions\\s+of\\s+this\\s+(?:Act|Order|Part)\\s*(?<self>\\(together\\s+with\\s+this\\s+section\\)\\s*)?(?:shall\\s+)?extend\\s+to\\s+(?<places>#{@place_list})\\s*,?\\s*(?:namely|that\\s+is\\s+to\\s+say)?\\s*,?\\s*[—–:]\\s*(?<list>[^.]*)",
                    "iu"
                  )
  # "Where any enactment amended or repealed by this Act extends to any part
  # of the United Kingdom, the amendment or repeal extends to that part"
  # (EPA 1990 s.164(5)): every amendment the law makes has the enactment's
  # extent
  @amendments_where ~r/^(?:\(\w+\)\s*)?Where\s+any\s+enactment\s+amended(?:\s+or\s+repealed)?\s+by\s+this\s+(?:Act|Order)\s+extends\s+to\s+any\s+part\s+of\s+the\s+United\s+Kingdom,\s+the\s+amendment(?:\s+or\s+repeal)?\s+extends\s+to\s+that\s+part\b/iu

  # "This Act, except— (a) …; and (b) …, does not extend to Northern Ireland"
  # (also "This Act, except this section and the following provisions,
  # namely— …, does not extend to Northern Ireland": Gas Act 1986 s.68(6),
  # CV-S05 D)
  @except_list Regex.compile!(
                 "#{@subject},\\s*except\\s*(?:for\\s*)?(?<self>this\\s+section\\s+and\\s+)?(?:the\\s+following\\s+provisions\\s*,?\\s*(?:namely|that\\s+is\\s+to\\s+say)?\\s*,?\\s*)?[—–:]\\s*(?<items>.+?),\\s*(?:does|do|shall)\\s+not\\s+extend\\s+to\\s+(?<places>#{@place_list})",
                 "isu"
               )
  # "Part III, except section 75 and Schedule 7, does not extend to Scotland"
  @part_not Regex.compile!(
              "(?<!provisions of )\\b(Parts?\\s+[IVXLC\\d]+[A-Z]*(?:\\s*(?:,|and)\\s*[IVXLC\\d]+[A-Z]*)*)(?:,\\s*except\\s+([^,]+),)?\\s+(?:does|do|shall)\\s+not\\s+extend\\s+to\\s+(#{@place_list})",
              "u"
            )
  # (also "Nothing in this Act extends to Scotland or Northern Ireland":
  # 1957/42, CV-S05)
  @not_extends Regex.compile!(
                 "(?:#{@subject}(?:,\\s*(?:apart from|except(?: for)?)\\s+([^,]+),)?\\s+(?:does|do|shall)\\s+not\\s+extend|\\bNothing\\s+in\\s+(?:this Act|these Regulations|this Order|these Rules)()\\s+(?:shall\\s+)?extends?)\\s+to\\s+((?>#{@place_list}))",
                 "iu"
               )

  @doc "The `@subject` form (its wording in the comment where it is defined)."
  @spec subject() :: String.t()
  def subject, do: @subject

  @doc "The `@heading` form (its wording in the comment where it is defined)."
  @spec heading() :: Regex.t()
  def heading, do: @heading

  @doc "The `@extends` form (its wording in the comment where it is defined)."
  @spec extends() :: Regex.t()
  def extends, do: @extends

  @doc "The `@extends_and` form (its wording in the comment where it is defined)."
  @spec extends_and() :: Regex.t()
  def extends_and, do: @extends_and

  @doc "The `@extends_exc` form (its wording in the comment where it is defined)."
  @spec extends_exc() :: Regex.t()
  def extends_exc, do: @extends_exc

  @doc "The `@cited_list` form (its wording in the comment where it is defined)."
  @spec cited_list() :: Regex.t()
  def cited_list, do: @cited_list

  @doc "The `@named` form (its wording in the comment where it is defined)."
  @spec named() :: Regex.t()
  def named, do: @named

  @doc "The `@amendments_same` form (its wording in the comment where it is defined)."
  @spec amendments_same() :: Regex.t()
  def amendments_same, do: @amendments_same

  @doc "The `@extends_except` form (its wording in the comment where it is defined)."
  @spec extends_except() :: Regex.t()
  def extends_except, do: @extends_except

  @doc "The `@only_following` form (its wording in the comment where it is defined)."
  @spec only_following() :: Regex.t()
  def only_following, do: @only_following

  @doc "The `@amendments_where` form (its wording in the comment where it is defined)."
  @spec amendments_where() :: Regex.t()
  def amendments_where, do: @amendments_where

  @doc "The `@except_list` form (its wording in the comment where it is defined)."
  @spec except_list() :: Regex.t()
  def except_list, do: @except_list

  @doc "The `@part_not` form (its wording in the comment where it is defined)."
  @spec part_not() :: Regex.t()
  def part_not, do: @part_not

  @doc "The `@not_extends` form (its wording in the comment where it is defined)."
  @spec not_extends() :: Regex.t()
  def not_extends, do: @not_extends
end
