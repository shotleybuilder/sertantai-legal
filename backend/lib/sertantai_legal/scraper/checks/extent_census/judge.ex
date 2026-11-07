defmodule SertantaiLegal.Scraper.Checks.ExtentCensus.Judge do
  @moduledoc """
  The census's verdicts: one named provision against the stored rows
  (ok, withheld, broader?, place, missing, q_read, q_missing, exc_held),
  and a whole-law statement against the stored default or application
  (ok, whole_missing, whole_mismatch) (`census.py`'s `judge`,
  `place_ok`, `whole`; #192).
  """

  alias SertantaiLegal.Scraper.Checks.ExtentCensus.{Places, Re, Segments, Stored}

  @whole_subj ~r/^\s*(?:(?:Subject\s+to|Except\s+as|Save\s+as|Without\s+prejudice\s+to|With\s+the\s+exception\s+of)\b[^,]*,\s*|(?:[;,]?\s*but\s+)?(?:,\s*)?save\s+as\s+(?:aforesaid|otherwise\s+provided)\s*,?\s*|In\s+this\s+\w+\s*[—–]\s*)?(?:this\s+(?:Act|Order|instrument)|these\s+(?:Regulations|Rules)|they|it)\b(?:\s*,[^,]*,)?\s+(?:\w+\s+){0,3}?(?<verb>extends?|appl(?:y|ies)|shall|does|do|is|are|also)\b/iu
  @apply ~r/\bappl(?:y|ies)\b/iu

  @doc "`WHOLE_SUBJ`: a statement whose subject is the whole law."
  @spec whole_subj() :: Regex.t()
  def whole_subj, do: @whole_subj

  @doc "Whether a stored row of `kind` and `place` states what the segment says."
  @spec place_ok?(String.t(), String.t() | nil, map()) :: boolean()
  def place_ok?(kind, _place, %{same: true}), do: kind == "same"

  def place_ok?(kind, place, %{neg: true, places: places}),
    do: kind in ["not", "applies_not", "unread"] and place == places

  def place_ok?(kind, place, %{places: places}),
    do: kind not in ["not", "applies_not", "same", "except", "unread"] and place == places

  @doc "One named ref's verdict, from the mention's marks and the segment's statement."
  @spec judge(String.t(), map(), map(), Stored.t()) :: String.t()
  def judge(ref, men, seg, stored) do
    {exact, cover} = Stored.where(stored, ref)
    good = Enum.any?(exact, fn {k, p} -> place_ok?(k, p, seg) end)

    cond do
      men.excepted -> if good and not seg.neg, do: "exc_held", else: "ok"
      Enum.any?(exact ++ cover, &(elem(&1, 0) == "unread")) -> "withheld"
      men.qualified not in [false, nil] -> qualified(good, exact, cover)
      good or the_default?(seg, stored, exact) -> "ok"
      true -> unheld(exact, cover, seg)
    end
  end

  # held for no place the segment states
  defp unheld(exact, cover, seg) do
    cond do
      Enum.any?(cover, fn {k, p} -> place_ok?(k, p, seg) end) -> "broader?"
      exact != [] or cover != [] -> "place"
      true -> "missing"
    end
  end

  defp qualified(true, _exact, _cover), do: "q_read"
  defp qualified(false, [], []), do: "q_missing"
  defp qualified(false, _exact, _cover), do: "ok"

  # a statement of the default's own places: the default holds it, unless a list names it
  defp the_default?(seg, stored, exact) do
    not seg.neg and not seg.same and seg.places == stored.default and
      not Enum.any?(exact, fn {k, _} -> k in ["only", "named", "also"] end)
  end

  @doc """
  A whole-law statement against the stored default / application: the
  places of its own clause (after the subject; never a "which shall apply
  to …" aside), extend and apply parts each against their own. Nil when
  it states no place.
  """
  @spec whole(map(), Stored.t()) :: String.t() | nil
  def whole(%{same: true}, _stored), do: nil

  def whole(seg, stored) do
    text =
      Regex.replace(~r/\bwhich\s+(?:shall\s+)?(?:extends?|appl(?:y|ies))\b[^,]*,/u, seg.text, " ")

    main =
      case Regex.run(@whole_subj, text, return: :index, capture: [:verb]) do
        [{at, _}] -> Re.from(text, at)
        nil -> text
      end

    out =
      ~r/\band\s+(?:shall\s+|does\s+|do\s+)?(?=(?:not\s+|only\s+)?appl(?:y|ies)\b)/u
      |> Re.split1(main)
      |> Enum.with_index()
      |> Enum.flat_map(fn {part, k} -> part_verdict(part, k, stored) end)

    Enum.find(out, &(&1 != "ok")) || if(out != [], do: "ok")
  end

  defp part_verdict(part, k, stored) do
    clause = Segments.first_clause(part)

    case Places.code(clause) do
      nil ->
        []

      places ->
        apply =
          k == 1 or (Regex.match?(@apply, part) and not Regex.match?(~r/\bextends?\b/u, part))

        held = if apply, do: stored.application, else: stored.default
        [held_verdict(held, places, Regex.match?(Segments.neg(), clause), part)]
    end
  end

  defp held_verdict(nil, _places, _neg, _part), do: "whole_missing"

  defp held_verdict(held, places, neg, part) do
    hs = MapSet.new(String.split(held, "+"))
    ss = MapSet.new(String.split(places, "+"))

    cond do
      neg -> if MapSet.disjoint?(hs, ss), do: "ok", else: "whole_mismatch"
      Regex.match?(~r/\balso\b/iu, part) -> "ok"
      hs == ss -> "ok"
      MapSet.subset?(ss, hs) and not Regex.match?(~r/\bonly\b/iu, part) -> "ok"
      true -> "whole_mismatch"
    end
  end
end
