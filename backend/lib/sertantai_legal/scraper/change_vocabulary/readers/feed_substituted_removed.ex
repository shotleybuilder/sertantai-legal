defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.FeedSubstitutedRemoved do
  @moduledoc """
  The provisions a changes-feed effect's Type says new text was
  substituted for that the effect does not land on: gone with the
  substitution. "sch. 1A Pt. C para. 3(b)(i)-(iii)" "substituted for sch.
  1A Pt. C para. 3(b)(i)-(iv)" (SSI 2014/364 by SSI 2022/387 reg.
  17(4)(b)(ii)) removes (iv); "s. 153(1)(a)-(nn)" "substituted for s.
  153(1)(a)-(aaa)" (EPA 1990 by SI 2015/479 art. 2, "for paragraphs (a) to
  (aaa) substitute—") removes (oo) to (aaa); "words substituted for s.
  73(11)(a)(b)" over "s. 73(11)" removes its paragraphs (a) and (b)
  (Waste, Water and Climate: Feed reader).

  The Type's provisions are read as the feed's affecting provisions are
  (`FeedAffecting`), a range as every number between its ends where they
  can be counted (numbers, letters, a long list's letters a to z then aa
  to zz, roman numerals), else its two ends. One is removed when the
  effect's own text surely does not name it (`FeedSubstitutedFor.names?`)
  and it stands beside a provision the effect lands on (under the same
  parent), or, for a change of words, under one. It is named as that
  target is. Nothing is read from a Type restating only a tail. Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Readers.{FeedAffecting, FeedSubstitutedFor}

  # a ref's own number with its parts, after what it stands under
  @number ~r/^(.*?)(\d+[A-Za-z]*(?:\([^)]+\))*)$/u
  # a range of bracketed letters
  @letters ~r/\(([a-z]+)\)\s*-\s*\(([a-z]+)\)/
  # a Part between a Schedule and its paragraph, which the Type's reading
  # leaves out
  @part ~r/pt\.[^.]+\./

  @doc """
  The provisions removed, as row refs: those `type` says were substituted
  for, which `text` (the effect's affected provisions) does not name,
  beside one of `targets` — or under one, where the change is of its
  words (`level`).
  """
  @spec removed(String.t() | nil, String.t() | nil, [String.t()], :provision | :words | nil) ::
          [String.t()]
  def removed(type, text, targets, level) do
    landed = targets |> Enum.map(&parts/1) |> Enum.reject(&is_nil/1)
    named = FeedSubstitutedFor.replaced(type)

    for old <- old(named),
        ref = placed(old, landed, level),
        # as the Type's own numbers read ("s. 6C6D" names no section 6)
        ref != nil and FeedSubstitutedFor.names?(named, ref),
        apart?(ref, text, targets, level),
        uniq: true,
        do: ref
  end

  # not a provision the effect lands on or names (a paragraph under the
  # provision whose words changed is never named by its text)
  defp apart?(ref, text, targets, level) do
    key(ref) not in Enum.map(targets, &key/1) and
      (level == :words or not FeedSubstitutedFor.names?(text, ref))
  end

  # the provisions the Type names, each as what it stands under, its
  # number's stem and its last part
  defp old(nil), do: []

  defp old(text) do
    text = text |> String.replace(~r/\bsch\b/, "Sch") |> String.replace(~r/\bArts?\b/, "art")
    ranges = for [_, from, to] <- Regex.scan(@letters, text), do: {to, between(from, to)}

    text
    |> FeedAffecting.refs()
    |> Enum.flat_map(&counted(&1, ranges))
    |> Enum.map(&parts/1)
    |> Enum.reject(&is_nil/1)
  end

  # a range of letters `FeedAffecting` gives by its ends, at its far end:
  # every number of it
  defp counted(ref, ranges) do
    Enum.find_value(ranges, [ref], fn {to, letters} ->
      if letters != [] and String.ends_with?(ref, "(#{to})"),
        do: Enum.map(letters, &String.replace_suffix(ref, "(#{to})", "(#{&1})"))
    end)
  end

  # "s.21(8)(c)" → {"s.", "21(8)", "(c)"}; "s.39A" → {"s.", "", "39A"}
  defp parts(ref) do
    with [_, under, number] <- Regex.run(@number, ref),
         {stem, [last]} <- number |> String.split(~r/(?=\()/u, trim: true) |> Enum.split(-1) do
      {under, Enum.join(stem), last}
    else
      _ -> nil
    end
  end

  # the removed provision named as the target it stands beside is named;
  # under a target, for a change of the target's words
  defp placed({under, stem, last}, landed, :provision) do
    Enum.find_value(landed, fn {t_under, t_stem, _} ->
      if same?(under, t_under) and key(stem) == key(t_stem), do: t_under <> t_stem <> last
    end)
  end

  defp placed({under, stem, last}, landed, :words) do
    Enum.find_value(landed, fn {t_under, t_stem, t_last} ->
      target = t_stem <> t_last

      if same?(under, t_under) and String.starts_with?(key(stem <> last), key(target) <> "("),
        do: t_under <> target <> String.slice(stem <> last, String.length(target)..-1//1)
    end)
  end

  defp placed(_old, _landed, _level), do: nil

  # under the same Schedule or kind: an EU article is the feed's "Art.", a
  # Part between a Schedule and its paragraph is not counted
  defp same?(under, t_under), do: place(under) == place(t_under)

  defp place(under),
    do: under |> key() |> String.replace("art.article ", "reg.") |> String.replace(@part, "")

  defp key(text), do: String.downcase(text)

  # the numbers from one end of a range of letters to the other: a long
  # list's ("a" to "aaa": a to z, aa to zz, aaa) or roman numerals ("i" to
  # "iv"); none for a range counted already or of no sure kind ("i" to "v")
  defp between(from, to) do
    cond do
      roman?(from) and roman?(to) and String.length(from <> to) > 2 -> romans(from, to)
      repeated?(from) and repeated?(to) and String.length(from <> to) > 2 -> long(from, to)
      true -> []
    end
  end

  defp repeated?(letters), do: letters =~ ~r/^([a-z])\1*$/
  defp roman?(letters), do: letters =~ ~r/^[ivx]+$/

  # the long list's letters in order, from `from` to `to`
  defp long(from, to) do
    all = for n <- 1..3, letter <- ?a..?z, do: String.duplicate(<<letter>>, n)

    all
    |> Enum.drop_while(&(&1 != from))
    |> Enum.split_while(&(&1 != to))
    |> case do
      {[_ | _] = before, [^to | _]} -> before ++ [to]
      _ -> []
    end
  end

  @numerals ~w(i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx)

  defp romans(from, to) do
    with a when is_integer(a) <- Enum.find_index(@numerals, &(&1 == from)),
         b when is_integer(b) and b > a <- Enum.find_index(@numerals, &(&1 == to)) do
      Enum.slice(@numerals, a..b)
    else
      _ -> []
    end
  end
end
