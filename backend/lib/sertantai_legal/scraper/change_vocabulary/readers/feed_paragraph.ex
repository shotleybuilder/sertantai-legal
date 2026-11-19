defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedParagraph do
  @moduledoc """
  A law's own numbered paragraph the changes feed names (`paragraph-2-1`,
  "para. 2(1)" of a Scheme: SI 2000/2911), as the XML id of the row the
  parse holds it under (`section-2-1`, row reg.2(1)): the text numbers a
  Scheme's body in paragraphs, its ids in sections. Pure.
  """

  @kinds ~w(section article regulation rule)

  @doc """
  The row's XML id for body paragraph id `id` among the rows' `xml_ids`:
  the one id of a body kind with the same numbers; nil for any other id,
  or where no row or more than one answers.
  """
  @spec id(String.t(), %{String.t() => String.t()}) :: String.t() | nil
  def id("paragraph-" <> numbers, xml_ids) do
    case for kind <- @kinds, x = kind <> "-" <> numbers, Map.has_key?(xml_ids, x), do: x do
      [one] -> one
      _none_or_several -> nil
    end
  end

  def id(_id, _xml_ids), do: nil
end
