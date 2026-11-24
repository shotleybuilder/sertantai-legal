defmodule SertantaiLegal.Scraper.Commencement.Order.Purposes do
  @moduledoc """
  How far a commencement order's item comes in: fully, for some purposes, or
  with provisions excepted.

  Pure; part of the order reader (`Commencement.Order`).
  """

  alias SertantaiLegal.Scraper.Commencement.Rule
  alias SertantaiLegal.Scraper.Commencement.Order.Words

  alias SertantaiLegal.Scraper.Commencement.Text.Sibling

  @doc "The subsections an aside excepts from `ref`."
  @spec excepted(String.t(), String.t()) :: [String.t()]
  def excepted(ref, aside), do: except_subsections("(" <> aside <> ")", [ref]) || []

  @doc "True when an aside limits its item (a purpose or extent) and does not complete it."
  @spec partial?(String.t()) :: boolean()
  def partial?(aside),
    do: Regex.match?(Words.partial(), aside) and not Regex.match?(Words.full(), aside)

  # "Section 33 (except subsection (1)(a) and (b))", "Section 4, apart from
  # subsection (6)" (SSI 2005/351): the section, but for
  # those (SI 1974/1439 Sch. 2, CV-S04 round 2); nil when it says none
  @doc "The section's refs but for the subsections the words except; nil when they except none."
  @spec except_subsections(String.t(), [String.t()]) :: [String.t()] | nil
  def except_subsections(text, [ref]) do
    with [_, list] <-
           Regex.run(
             ~r/(?:\(|,)\s*(?:except|apart\s+from|other\s+than)\s+(?:the\s+amendments?\s+made\s+by\s+)?(?:sub-?)?(?:sections?|paragraphs?)\s+((?:\([0-9A-Za-z]+\)|\s|,|and)+)(?:\)|[\s;.]*$)/i,
             text
           ),
         [_ | _] = chains <- Regex.scan(~r/(?:\([0-9A-Za-z]+\))+/, list) |> List.flatten() do
      subsection_refs(chains, ref)
    else
      _ -> nil
    end
  end

  def except_subsections(_text, _refs), do: nil

  # each excepted chain as a ref under `ref`, a bare "(b)" a sibling of the
  # chain before it
  defp subsection_refs(chains, ref) do
    number = String.replace(ref, ~r/^[a-z.]+\./i, "")
    prefix = String.replace_suffix(ref, number, "")

    chains
    |> Enum.map_reduce(nil, fn chain, last ->
      full = if last, do: Sibling.of(last, chain), else: number <> chain
      {prefix <> full, full}
    end)
    |> elem(0)
  end

  @doc "The purposes an item's own qualifier limits it to; nil for none, or one that completes it (\"so far as not already in force\")."
  @spec of_qualifier(String.t() | nil) :: Rule.purposes()
  def of_qualifier(qualifier) when qualifier in [nil, ""], do: nil

  def of_qualifier(qualifier),
    do: if(Regex.match?(Words.full(), qualifier), do: nil, else: purposes(qualifier))

  @doc "The purposes the words limit an item to; nil when none."
  @spec purposes(String.t()) :: Rule.purposes()
  def purposes(text) do
    cond do
      text =~
          ~r/\bmak(?:e|ing)\s+(?:regulations|an?\s+order|orders|rules|subordinate\s+legislation)\b|\bconfers?\s+(?:a\s+)?power\b|\b(?:regulations|orders|rules)\b[^.;]{0,90}?\bto\s+be\s+made\b/i ->
        :for_making_secondary_legislation

      text =~ ~r/\bspecified\s+purposes\b/i ->
        :for_specified_purposes

      true ->
        :in_relation_to
    end
  end
end
