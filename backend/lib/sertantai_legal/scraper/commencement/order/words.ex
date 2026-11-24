defmodule SertantaiLegal.Scraper.Commencement.Order.Words do
  @moduledoc """
  A commencement order's words normalised for reading (case, spaces, the day
  of a month), a rule's source ref, and the wordings the order reader's
  modules share.

  Pure; part of the order reader (`Commencement.Order`).
  """

  alias SertantaiLegal.Scraper.Commencement.ClmlRef

  @cif ~r/\b(?:shall\s+)?(?:come|comes)\s+into\s+(?:force|operation)\b/i

  # … "is the day appointed", "is the appointed day" (WSI 2011/824, CV-S04)
  @appointed ~r/\bis\s+the\s+(?:(?:day|date)\s+appointed|appointed\s+(?:day|date))\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b/i

  @appointed_is ~r/\bthe\s+(?:appointed\s+(?:day|date)|(?:day|date)\s+appointed)\s+for\s+the\s+coming\s+into\s+(?:force|operation)\s+of\b(.*)\bis\s+(.+)$/isu

  # ("Section 1, so far as not already commenced": SI 2010/2169 Sch.)
  @full ~r/\b(?:(?:in\s*)?so\s*far|insofar|in\s+as\s+far)\s+as\s+(?:it|they|th(?:at|ose|ese)\s+[\w-]+)\s+(?:has|have|is|are)\s+not\s+(?:already|previously|yet)\s+(?:been\s+)?(?:commenced|brought\s+into\s+force|in\s+(?:force|operation)|come\s+into\s+(?:force|operation))|(?:(?:in\s*)?so\s*far|insofar)\s+as\s+not\s+(?:already|previously|yet|then)\s+(?:in\s+(?:force|operation)|commenced|brought\s+into\s+force)|\bto\s+the\s+extent\s+(?:that\s+)?(?:it|they)\s+(?:is|are|has|have)\s+not\s+(?:already|yet)\s+(?:been\s+)?(?:commenced|brought\s+into\s+force|in\s+(?:force|operation)|come\s+into\s+(?:force|operation))|for\s+all\s+(?:remaining\s+|other\s+)?purposes|\(?\s*except\s+(?:in\s+)?so\s+far\s+as\s+(?:it\s+is\s+|they\s+are\s+)?already\s+in\s+(?:operation|force)\s*\)?|\(\s*except\s+as\s+aforesaid\s*\)/i

  @partial ~r/\bthe\s+following\s+repeals\b|\bso\s+much\s+of\b|\b(?:(?:in\s*)?so\s*far|insofar)\s+as\b|\bto\s+the\s+extent\b|\bfor\s+the\s+purposes?\s+(?:only\s+)?of\b|\bfor\s+(?:specified|certain|limited|particular)\s+purposes\b|\bexcept\b|\bsave\b|\bin\s+relation\s+to\b/i

  @entries_head ~r/\bthe\s+following\s+(?:repeals|entries)\b/i

  # a line's leading number label and the next item's trailing label ("… of— a")
  # an order's appointed-day words in the reader's own order: "The appointed
  # day for the following provisions of the Act coming into force is 25
  # January 2018—" (WSI 2018/35) as "… for the coming into force of the
  # following provisions of the Act is …"; "the 20th of May 2005" (SSI
  # 2005/256) as "the 20th May 2005"
  @appointed_for_coming ~r/\b(the\s+(?:appointed\s+(?:day|date)|(?:day|date)\s+appointed)\s+for)\s+(?!the\s+coming\b)(.+?)\s+coming\s+into\s+(force|operation)\s+is\b/isu

  # "14th December 2007 is the appointed day on which the following
  # provisions of the … Act 2003 come into force:–" (SSI 2007/530) as "The
  # following provisions … come into force on 14th December 2007:–"
  @day_on_which ~r/^\s*(\d{1,2}(?:st|nd|rd|th)?\s+\w+\s+\d{4})\s+is\s+the\s+(?:appointed\s+)?day\s+(?:appointed\s+)?on\s+which\s+(.+?)\s+(comes?)\s+into\s+(force|operation)\b/isu

  @day_of_month ~r/\b(\d{1,2}(?:st|nd|rd|th)?)\s+of\s+(January|February|March|April|May|June|July|August|September|October|November|December)\b/iu

  @doc "An order's words in the reader's form (\"the 1st of April\" → \"1st April\")."
  @spec wording(String.t()) :: String.t()
  def wording(text) do
    text
    |> String.replace(@day_on_which, "\\2 \\3 into \\4 on \\1")
    |> String.replace(@appointed_for_coming, "\\1 the coming into \\3 of \\2 is")
    |> String.replace(@day_of_month, "\\1 \\2")
  end

  @doc "A line of an order's text, in the reader's wording."
  @spec clean_line(String.t()) :: String.t()
  def clean_line(line) do
    line
    |> wording()
    # (never a date's day: "18 March 2011 is the appointed day …": WSI 2011/824)
    |> String.replace(
      ~r/^\(?\d+[A-Z]?\)?(?:\s+\(?\d+\)?)?\s+(?=[A-Z])(?!(?:January|February|March|April|May|June|July|August|September|October|November|December)\b)/u,
      ""
    )
    |> String.replace(
      ~r/[;,—–:]?\s*(?:and|or)?\s*\(?(?:[a-z]{1,2}|[ivx]{1,5}|\d{1,2})\)?\.?\s*$/u,
      fn m ->
        if m =~ ~r/[;—–:]/u, do: "", else: m
      end
    )
    |> String.trim()
  end

  @schedule_entries ~r/^\W*In\s+(?:the\s+Schedule|Schedule\s+(\d+[A-Z]*))?\s*(?:to\s+the\s+Act\s*)?[,—–:]\s*the\s+(repeals?|entr(?:y|ies))\b(.*)$/isu

  @doc "A CLML id in the law's ref grammar, else the id as given."
  @spec source_ref(String.t()) :: String.t()
  def source_ref(id), do: ClmlRef.ref(id) || id

  @doc "The text with its spaces collapsed and trimmed."
  @spec squash(String.t()) :: String.t()
  def squash(t), do: t |> String.replace(~r/\s+/u, " ") |> String.trim()

  @doc "The text lower case, words and numbers only."
  @spec norm(String.t()) :: String.t()
  def norm(t), do: t |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, " ") |> String.trim()

  # the order reader's shared wordings, for the modules that read with them
  @doc false
  def appointed, do: @appointed
  @doc false
  def appointed_is, do: @appointed_is
  @doc false
  def cif, do: @cif
  @doc false
  def entries_head, do: @entries_head
  @doc false
  def full, do: @full
  @doc false
  def partial, do: @partial
  @doc false
  def schedule_entries, do: @schedule_entries
end
