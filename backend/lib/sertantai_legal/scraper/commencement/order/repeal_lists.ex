defmodule SertantaiLegal.Scraper.Commencement.Order.RepealLists do
  @moduledoc """
  The repeals a commencement order's item or Schedule row lists, which name
  other laws' provisions, never ones the order brings in. An item: "section
  101(2) in so far as it relates to the following repeals specified in
  Schedule 9— (i) the repeals of sections 28, 30 and 194 of, and Schedule 4
  to, the WIA; …" (SI 2005/2714 art.2(m)). The sub-list names other laws'
  provisions, never ones the order brings in, as a statement's own "the
  following repeals" head does (SI 1996/3056); the item itself stays. Pure
  CLML.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  @opener ~r/\bthe\s+following\s+(?:repeals|revocations|entries)\b[^—–:;]*[—–:]\s*$/iu

  @doc """
  A Schedule table's rows without the entries under a row opening "the
  following repeals … –": the rows after it with no subject cell name other
  laws' provisions ("In the Pollution Control … Order 1978 – | Articles 3, 5
  to 13, 16 and 18;": NISR 2003/489), never ones the order brings in; the
  opening row itself stays. A row with a subject ends them.
  """
  @spec drop_table_entries([[String.t()]]) :: [[String.t()]]
  def drop_table_entries(rows) do
    rows
    |> Enum.map_reduce(false, fn cells, in_list? ->
      cond do
        in_list? and subjectless?(cells) -> {nil, true}
        opens_row?(cells) -> {cells, true}
        true -> {cells, false}
      end
    end)
    |> elem(0)
    |> Enum.reject(&is_nil/1)
  end

  defp opens_row?([first | _]), do: first =~ @opener
  defp opens_row?(_cells), do: false

  defp subjectless?([_first | rest]), do: Enum.all?(rest, &(String.trim(&1) == ""))
  defp subjectless?(_cells), do: false

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
