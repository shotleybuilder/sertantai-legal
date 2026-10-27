defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.MakesFollowing do
  @moduledoc """
  The law's extent "so far as it makes the following provision" (CV-S05
  round 10; Police Reform Act 2002 s.108(7)): "This Act extends to the
  United Kingdom so far as it makes the following provision— (za) the
  provision contained in paragraph 19F of Schedule 3 (and any interpretative
  or other supplementary provision …); (a) the provision contained in Part
  5; (b) the provision contained in section 82; (c) . . .; (d) the provision
  contained in section 103(6)" → `{:named, "E+W+S+NI", refs}`: the
  provisions named (a default it widens). A bracketed aside (the
  supplementary provision, not named) and a repealed item (". . .") name
  none; an item that isn't "the provision contained in …" leaves the
  sentence unread. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.AmendingLaw.Extent.{Parts, Places}

  @place_list Places.place_list()
  @form Regex.compile!(
          "^\\s*(?:\\(?\\d+\\)?\\s*)?(?:This\\s+Act|These\\s+Regulations|This\\s+Order)\\s+(?:shall\\s+)?extends?\\s+to\\s+(?<places>(?>#{@place_list}))\\s+(?:in\\s+)?so\\s+far\\s+as\\s+it\\s+makes\\s+the\\s+following\\s+provision\\s*[—–:]\\s*(?<items>.+)$",
          "isu"
        )

  @contained ~r/^the\s+provisions?\s+contained\s+in\s+/iu

  @doc "The list `s` (in provision `ref`) states, or nil when `s` isn't this form or an item isn't read."
  @spec list(String.t(), String.t(), Doc.t()) :: {:named, String.t(), [String.t()]} | nil
  def list(s, ref, %Doc{} = doc) do
    with %{} = m <- Regex.named_captures(@form, s),
         items = items(m["items"]),
         true <- items != [] and Enum.all?(items, &(&1 =~ @contained)),
         named = Enum.map(items, &named(String.replace(&1, @contained, ""), ref, doc)),
         false <- [] in named do
      {:named, Places.places(m["places"]), named |> List.flatten() |> Enum.uniq()}
    else
      _ -> nil
    end
  end

  defp named(item, ref, doc),
    do: Enum.uniq(RefList.parse(item, ref) ++ Parts.parts(item, doc, ref))

  @doc "The lists read from the unit sentences (`Units.unit_sentences/1`)."
  @spec lists([{String.t(), String.t()}], Doc.t()) :: [{:named, String.t(), [String.t()]}]
  def lists(unit_sentences, doc) do
    for {ref, s} <- unit_sentences, l = list(s, ref, doc), l != nil, uniq: true, do: l
  end

  # the lettered items, asides out, repealed ones (no words left) dropped
  defp items(text) do
    text
    |> String.replace(~r/\((?=[^()]*\s)(?:[^()]|\([^()]*\))*\)/u, " ")
    |> String.split(
      ~r/(?:^|[;.]|\s)\s*(?:and\s*)?\(?z?[a-z]\)?\s+(?=the\s+provisions?\s+contained\b|\.\s*\.)/iu
    )
    |> Enum.map(&(&1 |> String.trim() |> String.trim_trailing(";") |> String.trim()))
    |> Enum.reject(&(&1 =~ ~r/^[\s.;,]*(?:and)?[\s.;,]*$/u))
  end
end
