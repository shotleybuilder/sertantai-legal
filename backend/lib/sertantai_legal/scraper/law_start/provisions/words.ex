defmodule SertantaiLegal.Scraper.LawStart.Provisions.Words do
  @moduledoc """
  The words the provision readers share: a row's sentences and provision, and the patterns several of them match ("comes into force", a qualifier, a list's subject, another law's list). Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.Clause

  @cif ~r/\b(?:shall\s+(?:,[^,]{0,160},\s*)?)?(?:comes?|came)\s+into\s+(?:force|operation)\b/i

  @doc "\"comes into force\"."
  @spec cif() :: Regex.t()
  def cif, do: @cif

  @qualified ~r/\b(?:so far as|in so far as|insofar as|for the purposes? (?:only )?of|in relation to|with respect to|to the extent|for (?:all )?other purposes|into\s+(?:force|operation)\s+in\s+(?:England|Wales|Scotland|Northern Ireland|Great Britain)\b)\b/i

  @doc "A qualifier (\"so far as\", \"for the purposes of\", \"in relation to\" …)."
  @spec qualified() :: Regex.t()
  def qualified, do: @qualified

  # a list's head: "The following provisions …—", or "These provisions …—"
  # (2005 c.16 s.108(4))
  @list_subject ~r/\bthe following\b|^\W*(?:\(\w+\)\s*)?These\s+provisions\b/i

  @doc "A list's head (\"The following provisions …—\")."
  @spec list_subject() :: Regex.t()
  def list_subject, do: @list_subject

  # a list another law heads: a commencement order's "The following
  # provisions of the 2014 Act come into force on 6th March 2017—" (SI
  # 2017/58 art.2) lists that Act's sections, never the order's articles.
  # The Act is named or dated: a bare "the Act" may be the Act speaking of
  # itself ("The following provisions of the Act shall come into force …,
  # namely—": EPA 1990 s.164(2))
  @other_law_list ~r/\b[Tt]he\s+following\s+(?:provisions\s+)?of\s+(?:the|that)\s+(?:\d{4}\s+|(?:[A-Z][\w()',-]*\s+){1,12})(?:Act|Order|Regulations|Measure)\b/

  @doc "A list another law heads (\"The following provisions of the 2014 Act …\")."
  @spec other_law_list() :: Regex.t()
  def other_law_list, do: @other_law_list

  @doc "A row's text as sentences."
  @spec sentences(map()) :: [String.t()]
  def sentences(row), do: Clause.sentences(Map.get(row, :text) || "")

  @doc "A row's provision: its section id without paragraphs."
  @spec provision(String.t()) :: String.t()
  def provision(section_id), do: section_id |> String.split("(", parts: 2) |> hd()
end
