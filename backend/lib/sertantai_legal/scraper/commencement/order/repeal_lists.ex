defmodule SertantaiLegal.Scraper.Commencement.Order.RepealLists do
  @moduledoc """
  A commencement order's item listing the repeals it relates to: "section
  101(2) in so far as it relates to the following repeals specified in
  Schedule 9— (i) the repeals of sections 28, 30 and 194 of, and Schedule 4
  to, the WIA; …" (SI 2005/2714 art.2(m)). The sub-list names other laws'
  provisions, never ones the order brings in, as a statement's own "the
  following repeals" head does (SI 1996/3056); the item itself stays. Pure
  CLML.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  @opener ~r/\bthe\s+following\s+(?:repeals|revocations|entries)\b[^—–:;]*[—–:]\s*$/iu

  @doc "`el` without the sub-lists under its items that open \"the following repeals—\"."
  @spec prune(tuple()) :: tuple()
  def prune({:xmlElement, _, _, _, _, _, _, _, content, _, _, _} = el) do
    content =
      if opener?(content),
        do: Enum.reject(content, &sub_item?/1),
        else: Enum.map(content, &prune/1)

    put_elem(el, 8, content)
  end

  def prune(node), do: node

  # a para whose own Text opens the list
  defp opener?(content) do
    Enum.any?(content, fn
      {:xmlElement, :Text, _, _, _, _, _, _, _, _, _, _} = text -> Doc.text(text) =~ @opener
      _ -> false
    end) and Enum.any?(content, &sub_item?/1)
  end

  defp sub_item?({:xmlElement, name, _, _, _, _, _, _, _, _, _, _}),
    do: Atom.to_string(name) =~ ~r/^P\d$/

  defp sub_item?(_node), do: false
end
