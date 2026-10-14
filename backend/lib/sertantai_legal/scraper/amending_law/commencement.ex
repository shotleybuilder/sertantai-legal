defmodule SertantaiLegal.Scraper.AmendingLaw.Commencement do
  @moduledoc """
  When an amending provision came into force by the amending law's own
  words (lat-refactor LR-08): `{:date, date, provision}` when the law fixes
  it — an SI's single "shall come into force on 10th August 2000"; an Act
  "on the passing of this Act" or "at the end of the period of two months
  beginning with the day on which it is passed" (from `ukm:EnactmentDate`) —
  `:by_order` when it is "such day as … may by order appoint", `:unknown`
  otherwise (a provision the commencement words except, mixed or unread
  forms). Never a date it can't read; the commencing order is hop 2. Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}

  @months ~w(january february march april may june july august september october november december)
  @date ~r/(\d{1,2})(?:st|nd|rd|th)? (January|February|March|April|May|June|July|August|September|October|November|December),? (\d{4})/i
  @si ~w(uksi ssi wsi nisr)

  @doc "The provision `id`'s commencement by the law's own words (`found`: `provisions/1`, read once per law)."
  @spec of(Doc.t(), String.t(), [{String.t(), String.t()}] | nil) ::
          {:date, Date.t(), String.t()} | :by_order | :unknown
  def of(doc, id, found \\ nil) do
    case found || provisions(doc) do
      [] -> :unknown
      found -> rule(doc, id, found)
    end
  end

  @doc "{provision id, its words} for each provision with commencement words."
  @spec provisions(Doc.t()) :: [{String.t(), String.t()}]
  def provisions(doc) do
    for cid <- doc.ids,
        w = Text.words_of(doc, cid),
        Regex.match?(~r/c[oa]mes? into (?:force|operation)/i, w),
        do: {cid, w}
  end

  defp rule(%Doc{type: type}, _id, found) when type in @si do
    dates = for {cid, w} <- found, d <- dates(w), do: {cid, d}

    if length(Enum.uniq_by(dates, &elem(&1, 1))) == 1 and
         not Enum.any?(found, fn {_, w} -> w =~ ~r/\bexcept\b|\bsave\b|by order/i end),
       do: {:date, elem(hd(dates), 1), elem(hd(dates), 0)},
       else: :unknown
  end

  defp rule(doc, id, found) do
    case Enum.find(found, fn {_, w} -> w =~ ~r/^This Act\b/i end) do
      nil -> :unknown
      {cid, w} -> act(doc, id, cid, w)
    end
  end

  defp act(doc, id, cid, w) do
    cond do
      excepted?(id, cid, w) ->
        :unknown

      w =~ ~r/such day as .* appoint/i ->
        :by_order

      w =~ ~r/on the passing of this Act|on the day on which (?:this Act|it) is passed/i ->
        passed(doc, cid, 0)

      w =~
          ~r/end of the period of two months beginning with the day on which (?:this Act|it) is passed/i ->
        passed(doc, cid, 2)

      (d = dates(w)) != [] and length(d) == 1 ->
        {:date, hd(d), cid}

      true ->
        :unknown
    end
  end

  # "(apart from this section and section 68)": those provisions follow
  # other words, unread here
  defp excepted?(id, cid, w) do
    top = top(id)

    top == top(cid) or
      case Regex.run(~r/apart from ([^)]*)\)/i, w) do
        [_, list] ->
          top in for [n] <- Regex.scan(~r/(\d+[A-Z]*)/, list, capture: :all_but_first),
                     do: "section-#{n}"

        nil ->
          false
      end
  end

  defp passed(%Doc{enactment_date: nil}, _cid, _months), do: :unknown

  defp passed(%Doc{enactment_date: d}, cid, months),
    do: {:date, Date.shift(d, month: months), cid}

  defp top(id), do: id |> String.split("-") |> Enum.take(2) |> Enum.join("-")

  defp dates(w) do
    for [_, day, month, year] <- Regex.scan(@date, w) do
      m = Enum.find_index(@months, &(&1 == String.downcase(month))) + 1
      Date.new!(String.to_integer(year), m, String.to_integer(day))
    end
  end
end
