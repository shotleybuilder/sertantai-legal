defmodule SertantaiLegal.Scraper.AmendingLaw.Extent.ScheduleWords do
  @moduledoc """
  A Schedule a sentence names only by reference, made plain (CV-S05 rounds
  9 and 10; out of `Units`): "… of that Schedule" is the law's own Schedule
  named just before (ERRA 2013 s.102(4)); a lettered item's bare
  "paragraph 182(3)" is the Schedule the sentence named before it (SI
  2014/469 art.3(5)(d)). Never another law's ("Schedule 2 to the … Act
  1975"). Pure.
  """

  @doc "The text with \"that Schedule\" and lettered items' bare paragraphs named."
  @spec resolve(String.t()) :: String.t()
  def resolve(text), do: text |> that_schedule() |> bare_paragraphs()

  # a lettered item's bare paragraph is the Schedule's the sentence named
  # before it: "The amendments made by Schedule 3 have the same extent …,
  # except that— … (d) the amendments made by paragraph 182(3) and (5)
  # apply in relation to Wales only" (SI 2014/469 art.3(5)(d), CV-S05
  # round 10)
  defp bare_paragraphs(text) do
    with true <- text =~ ~r/\b(?:extends?|appl(?:y|ies))\b/u,
         [{dash, _} | _] <- Regex.run(~r/[—–]/u, text, return: :index),
         [_ | _] = mentions <- own_schedules(text) do
      ~r/\b(made\s+by)\s+((?>paragraphs?\s+\d+[A-Z]*(?:\(\w+\))*(?:\s*(?:,|and|to)\s*(?:\d+[A-Z]*(?:\(\w+\))*|(?:\(\w+\))+))*))(?!\s*(?:of|to)\b)/u
      |> Regex.scan(text, return: :index)
      |> Enum.reverse()
      |> Enum.reduce(text, fn [{at, len} | _], acc ->
        case at > dash && mentions |> Enum.filter(&(elem(&1, 0) < at)) |> List.last() do
          {_, n, false} ->
            whole = binary_part(acc, at, len)

            binary_part(acc, 0, at) <>
              whole <>
              " of Schedule #{n}" <>
              binary_part(acc, at + len, byte_size(acc) - at - len)

          _ ->
            acc
        end
      end)
    else
      _ -> text
    end
  end

  # "… paragraphs 15 to 44 … of Schedule 6 extend …; (b) paragraphs 52 to
  # 68 … of that Schedule extend …" (ERRA 2013 s.102(4), CV-S05 round 9):
  # the nearest Schedule named before, where it is the law's own (never
  # "Schedule 2 to the … Act 1975")
  defp that_schedule(text) do
    if text =~ ~r/\bof\s+that\s+Schedule\b/u do
      resolve_that(text, own_schedules(text))
    else
      text
    end
  end

  # each Schedule named, where, and whether another law's ("Schedule 2 to
  # the … Act 1975")
  defp own_schedules(text) do
    for [{at, _}, {n_at, n_len} | rest] <-
          Regex.scan(
            ~r/\bSchedule\s+(\d+[A-Z]*)\b(\s+(?:to|of)\s+(?:the|that)\s+(?:[A-Z]|\d{4}))?/u,
            text,
            return: :index
          ),
        do: {at, binary_part(text, n_at, n_len), match?([{s, _}] when s >= 0, rest)}
  end

  defp resolve_that(text, mentions) do
    ~r/\bof\s+that\s+Schedule\b/u
    |> Regex.scan(text, return: :index)
    |> Enum.reverse()
    |> Enum.reduce(text, fn [{at, len}], acc ->
      case mentions |> Enum.filter(&(elem(&1, 0) < at)) |> List.last() do
        {_, n, false} ->
          binary_part(acc, 0, at) <>
            "of Schedule #{n}" <>
            binary_part(acc, at + len, byte_size(acc) - at - len)

        _ ->
          acc
      end
    end)
  end
end
