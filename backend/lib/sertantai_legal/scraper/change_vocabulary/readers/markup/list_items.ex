defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.ListItems do
  @moduledoc """
  EU law's numbered list items with no id of their own (`<ListItem
  NumberOverride="(f)">`, `"18."`): the LAT holds each as a row named from
  the provision above it and the number (`art.Article 23(f)`,
  `art.Article 3(18)`), so the markup reader places a change inside one
  there, as the feed does — not on the Article as words (CV-S08 round 2:
  REACH Art 3(18), CLP Art 2(17); CLP Art 23(e)'s ";" had joined (f)).

  An item's id is its provision's CLML id and its number (`article-23-f`),
  which `Ref.from_clml/2` names as the row. Its number is an attribute, never
  wrapped by a change: a change round all of its text is the whole item.
  Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  @eu ~w(eur eudr eudn)

  @doc "The id of an id-less EU list item under `path` (row ids, outermost first); else nil."
  @spec id(atom(), list(), [String.t()], String.t() | nil) :: String.t() | nil
  def id(:ListItem, attrs, [_ | _] = path, law) do
    with true <- eu?(law),
         nil <- attr(attrs, :id),
         number when is_binary(number) <- attr(attrs, :NumberOverride),
         [_, n] <- Regex.run(~r/^\s*\(?([0-9]+[A-Za-z]*|[a-z]{1,4})\)?\.?\s*$/, number) do
      List.last(path) <> "-" <> n
    else
      _ -> nil
    end
  end

  def id(_name, _attrs, _path, _law), do: nil

  @doc "Each id-less EU list item's own text (letters and digits), by its id (nested items by theirs)."
  @spec own_texts(tuple(), String.t() | nil) :: %{String.t() => String.t()}
  def own_texts(doc, law) do
    if eu?(law), do: doc |> walk([], law) |> Map.new(), else: %{}
  end

  defp walk({:xmlElement, name, _, _, _, _, _, attrs, children, _, _, _} = el, path, law) do
    {path, own} =
      case attr(attrs, :id) || id(name, attrs, path, law) do
        nil ->
          {path, []}

        id ->
          own = if attr(attrs, :id), do: [], else: [{id, letters(el)}]
          {path ++ [id], own}
      end

    own ++ Enum.flat_map(children, &walk(&1, path, law))
  end

  defp walk(_other, _path, _law), do: []

  defp letters(el), do: el |> Doc.text() |> String.replace(~r/[^\p{L}\p{N}]/u, "")

  defp eu?(nil), do: false
  defp eu?(law), do: Enum.at(String.split(law, "_"), 1) in @eu

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} -> to_string(value)
      _ -> nil
    end)
  end
end
