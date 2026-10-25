defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.Same do
  @moduledoc """
  Provisions having the same extent as the enactments they change (CV-S05;
  decomposed from `AmendingLaw.Extent`, run time 2026-10-25): "The
  amendments and repeals in Schedules 20 and 21 have the same extent as the
  enactments to which they refer" → `{:same, nil, ["sch.20", "sch.21"]}`;
  "… made by this Act" → `["*"]`; with the exceptions stated after it, or
  `:unread` where they don't read plainly. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Forms, Named, Parts, Places}

  @place_list Places.place_list()

  # "Sections 240 and 242 and Schedules 1 and 3 have the same extent as the
  # provisions amended" (1996/18 s.244(4): CV-S05)
  @named_same ~r/^(?:\(\w+\)\s*)?(?<subj>(?:Sections?|Schedules?|Parts?|paragraphs?|regulations?|articles?)\s+[\dIVXL][^.;:—–]*?)\s+(?:has|have|shall\s+have)\s+the\s+same\s+extent\s+(?:within\s+the\s+United\s+Kingdom\s+)?as\s+the\s+(?:enactments?|provisions?)\s+(?:amended|repealed|revoked|modified|to\s+which\s+(?:it|they)\s+relates?)\b/iu

  # "This Act does not extend to Northern Ireland except so far as it
  # affects other enactments extending to Northern Ireland" (1988/54,
  # 1989/13, 1997/11): the default stands, and every amendment the law
  # makes follows the enactment it changes (CV-S05)
  @not_extends_amending ~r/\bnot\s+extend\s+to\s+[^.]*?\bexcept\b[^.]*?\bso\s+far\s+as\s+(?:it|they)\s+(?:affects?|amends?|repeals?|revokes?)\s+(?:any\s+)?(?:other\s+)?enactments?\b/iu

  @doc """
  The provisions with the same extent as the enactments they change, from
  the unit sentences (`Units.unit_sentences/1`): `{:same, nil, refs}` ("*"
  for every amendment the law makes), with any list its exceptions state.
  """
  @spec amendments_same([{String.t(), String.t()}], Doc.t()) :: [
          {atom(), String.t() | nil, [String.t()]}
        ]
  def amendments_same(unit_sentences, doc) do
    for(
      {ref, s} <- unit_sentences,
      m = Regex.named_captures(Forms.amendments_same(), s),
      m != nil,
      [_, tail] <- [Regex.split(Forms.amendments_same(), s, parts: 2)],
      not Regex.match?(
        ~r/\b(?:other\s+than|apart\s+from|except|save|excluding)\b/iu,
        m["subj"]
      ),
      refs = same_refs(m["subj"], tail, ref, doc),
      refs != :none,
      list <- same_lists(refs, tail, ref),
      uniq: true,
      do: list
    ) ++
      for(
        {_ref, s} <- unit_sentences,
        Regex.match?(Forms.amendments_where(), s) or Regex.match?(@not_extends_amending, s),
        uniq: true,
        do: {:same, nil, ["*"]}
      ) ++
      for {ref, s} <- unit_sentences,
          m = Regex.named_captures(@named_same, s),
          m != nil,
          not Regex.match?(Named.excepted(), m["subj"]),
          refs = Enum.uniq(RefList.parse(m["subj"], ref) ++ Parts.parts(m["subj"], doc, ref)),
          refs != [],
          uniq: true,
          do: {:same, nil, refs}
  end

  # the same extent, with its exceptions: none → same; "except that the
  # amendments made by paragraphs 11 to 13 of that Schedule extend to
  # Scotland only" → same, and those paragraphs only there; any other
  # exception → the provisions' extent is unknown (`:unread`), never the
  # default (SI 2014/469 art.3(5): CV-S05 round 3 E)
  defp same_lists(refs, tail, ref) do
    cond do
      not Regex.match?(~r/^[^—–]*?\b(?:except|save|but)\b/iu, tail) ->
        [{:same, nil, refs}]

      (m =
         Regex.named_captures(
           ~r/^(?:\s+(?:which|to\s+which|being)\b[^,;—–]*)?\s*,?\s*except\s+that\s+the\s+(?:amendments?|modifications?|repeals?|revocations?)\s+(?:made\s+by|specified\s+in)\s+(?<paras>paragraphs?\s+[^,;:—–]+?)\s+of\s+that\s+Schedule\s+(?:shall\s+)?(?<not>do\s+not\s+)?extends?\s+to\s+(?<places>(?>#{@place_list}))(?<only>\s+only)?\s*\.?\s*$/iu,
           tail
         )) && match?([<<"sch.", _::binary>>], refs) ->
        [sch] = refs
        n = String.replace_prefix(sch, "sch.", "")
        paras = RefList.parse("#{m["paras"]} of Schedule #{n}", ref)
        kind = if m["not"] != "", do: :not, else: :only

        if paras == [],
          do: [{:unread, nil, refs}],
          else: [{:same, nil, refs}, {kind, Places.places(m["places"]), paras}]

      true ->
        [{:unread, nil, refs}]
    end
  end

  defp same_refs(subj, tail, ref, doc) do
    # "made by the provisions in Parts 2 and 3": those Parts (uksi
    # 2023/1071 reg.1(2): CV-S05 round 4 N-A)
    subj = Regex.replace(~r/\bprovisions\s+(?:in|of)\s+(?=Parts?\s+[\dIVXL])/iu, subj, "")

    cond do
      subj =~ ~r/\bfollowing\b/i ->
        case tail |> String.split(~r/[—–:]/u, parts: 2) do
          [_, list] -> with([] <- RefList.parse(list, ref), do: :none)
          _ -> :none
        end

      # "made by Parts 4, 5 and 6", "made by regulations 3, 4, 6": those
      # (CV-S05 N13); a subject naming provisions not read is no "*"
      subj =~
          ~r/\b(?:sections?|regulations?|articles?|rules?|Parts?|Schedules?|paragraphs?)\s+[\dIVXL]/i ->
        case Enum.uniq(RefList.parse(subj, ref) ++ Parts.parts(subj, doc, ref)) do
          [] -> :none
          refs -> refs
        end

      true ->
        ["*"]
    end
  end
end
