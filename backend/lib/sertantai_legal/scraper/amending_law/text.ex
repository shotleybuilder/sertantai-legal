defmodule SertantaiLegal.Scraper.AmendingLaw.Text do
  @moduledoc """
  An amending provision's own words (lat-refactor LR-08): its `instruction`
  ("After subsection (5) of that section there is inserted—"), its `quoted`
  words (InlineAmendment / BlockAmendment: what is inserted or substituted,
  never an instruction), and its `context` — the instructions before it in
  the same top provision, in document order ("The 1989 Act is amended as
  follows.", "In section 40 …—"), for law names and "that section".
  Notes (Commentary, CommentaryRef), numbers and sub-provisions with their
  own id are left out. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  @enforce_keys [:id, :instruction]
  defstruct [:id, :instruction, quoted: "", context: []]

  @type t :: %__MODULE__{
          id: String.t(),
          instruction: String.t(),
          quoted: String.t(),
          context: [String.t()]
        }

  @notes ~w(Commentary CommentaryRef)a
  @numbers ~w(Pnumber Number Title)a
  @quoted ~w(InlineAmendment BlockAmendment)a

  @doc "The element's text; nil when the element isn't held."
  @spec of(Doc.t(), String.t()) :: t() | nil
  def of(doc, id) do
    case Doc.element(doc, id) do
      nil ->
        nil

      el ->
        {words, quoted} = words(el)
        top = top(id)

        context =
          for other <- Enum.take_while(doc.ids, &(&1 != id)),
              other == top or String.starts_with?(other, top <> "-"),
              {w, _} = words(Doc.element(doc, other)),
              w != "",
              do: w

        %__MODULE__{id: id, instruction: words, quoted: quoted, context: context}
    end
  end

  # the top provision: section-60 for section-60-5, schedule-6-paragraph-33
  # for schedule-6-paragraph-33-c
  defp top(id) do
    case Regex.run(
           ~r/^(schedule-[^-]+-paragraph-[^-]+|(?:section|regulation|article|rule)-[^-]+)/,
           id
         ) do
      [_, top] -> top
      nil -> id
    end
  end

  # {own words, quoted words}: sub-elements with an id are their own provisions
  defp words(el) do
    {own, quoted} = collect(content(el), {[], []}, false)
    {squash(own), squash(quoted)}
  end

  defp collect(nodes, acc, in_quote), do: Enum.reduce(nodes, acc, &node(&1, &2, in_quote))

  defp node({:xmlText, _, _, _, value, _}, {own, quoted}, false),
    do: {[to_string(value) | own], quoted}

  defp node({:xmlText, _, _, _, value, _}, {own, quoted}, true),
    do: {own, [to_string(value) | quoted]}

  defp node({:xmlElement, name, _, _, _, _, _, attrs, children, _, _, _}, acc, in_quote) do
    cond do
      name in @notes -> acc
      # a number outside a quote is the provision's own; inside, the inserted
      # provision's ("5A")
      name in @numbers and not in_quote -> acc
      name in @quoted -> collect(children, acc, true)
      not in_quote and Enum.any?(attrs, &(elem(&1, 1) == :id)) -> acc
      true -> collect(children, acc, in_quote)
    end
  end

  defp node(_other, acc, _in_quote), do: acc

  defp content({:xmlElement, _, _, _, _, _, _, _, children, _, _, _}), do: children

  defp squash(parts),
    do: parts |> Enum.reverse() |> Enum.join() |> String.replace(~r/\s+/u, " ") |> String.trim()
end
