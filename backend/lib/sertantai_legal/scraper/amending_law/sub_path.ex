defmodule SertantaiLegal.Scraper.AmendingLaw.SubPath do
  @moduledoc """
  A run of subdivision brackets as a law writes it, each as a path of labels
  (CV-S05 round 13, S2: found by the CV-S05d census). "(2)(a), (b) and (d)"
  → `[["2", "a"], ["2", "b"], ["2", "d"]]`; "(w)(i) and (ii)" → `[["w",
  "i"], ["w", "ii"]]`; "(1A), (2)(b) and (2ZZA) to (2ZZC)" → `[["1A"],
  ["2", "b"], ["2ZZA"], ["2ZZC"]]`.

  A bracket continuing the one before replaces it at its own level: a
  number replaces a number, a letter a letter, a roman numeral one under a
  letter ("(i)" after "(h)" is a letter). A range is spelt out where its
  ends are numbers ("(4) to (8A)": 4 to 8, and 8A) or single letters ("(b)
  to (d)"); else its ends. Pure.
  """

  @label ~r/\(([^()\s]{1,6})\)/u

  @doc "The paths a run of brackets names, each continuing the one before (from `start`)."
  @spec paths(String.t(), [String.t()]) :: [[String.t()]]
  def paths(text, start \\ []) do
    text
    |> String.split(~r/\s*(?:,\s*(?:and|or)?|\band\b|\bor\b)\s*/u, trim: true)
    |> Enum.reduce({[], start}, fn piece, {acc, last} ->
      case String.split(piece, ~r/\s+to\s+/u, parts: 2) do
        [a, b] ->
          from = continue(last, labels(a))
          to = continue(from, labels(b))
          {acc ++ range(from, to), to}

        [one] ->
          case labels(one) do
            [] ->
              {acc, last}

            subs ->
              path = continue(last, subs)
              {acc ++ [path], path}
          end
      end
    end)
    |> elem(0)
  end

  @doc "The labels of a bracket run: \"(2)(b)\" → [\"2\", \"b\"]."
  @spec labels(String.t()) :: [String.t()]
  def labels(text), do: for([_, l] <- Regex.scan(@label, text), do: l)

  @doc "`new` continuing `last`: it replaces `last` from the first label at its own level."
  @spec continue([String.t()], [String.t()]) :: [String.t()]
  def continue(last, []), do: last

  def continue(last, [first | _] = new) do
    levels = levels(last)
    # (a sibling: "(ii)" after "(w)(i)" is a roman numeral; "(i)" after
    # "(2)(h)", and "(x)" after "(w)(ii)", the next letter)
    level =
      cond do
        first =~ ~r/^\d/ -> :n
        roman?(first) and :r in levels and not next_letter?(last, levels, first) -> :r
        true -> :a
      end

    keep = Enum.find_index(levels, &(&1 == level)) || length(last)
    Enum.take(last, keep) ++ new
  end

  @doc """
  Each label's level within one path: `:n` (number), `:a` (letter), `:r`
  (a roman numeral under a letter: "(w)(i)").
  """
  @spec levels([String.t()]) :: [:n | :a | :r]
  def levels(path) do
    Enum.reduce(path, [], fn label, acc ->
      level =
        cond do
          label =~ ~r/^\d/ -> :n
          roman?(label) and List.last(acc) in [:a, :r] -> :r
          true -> :a
        end

      acc ++ [level]
    end)
  end

  defp next_letter?(last, levels, label) do
    case for({l, :a} <- Enum.zip(last, levels), do: l) |> List.last() do
      <<c>> -> label == <<c + 1>>
      _ -> false
    end
  end

  defp roman?(label), do: label =~ ~r/^(?:i{1,3}|iv|vi{0,3}|ix|x)$/

  # the paths between two ends at their last level
  defp range(from, to) do
    pre = Enum.drop(from, -1)
    a = List.last(from)
    b = List.last(to)

    cond do
      pre != Enum.drop(to, -1) -> [from, to]
      a =~ ~r/^\d+$/ and b =~ ~r/^\d+[A-Z]*$/ -> numbers(pre, a, b, to)
      a =~ ~r/^[a-z]$/ and b =~ ~r/^[a-z]$/ and a <= b -> letters(pre, a, b)
      true -> [from, to]
    end
  end

  # "(4) to (8A)": 4 to 8, and 8A
  defp numbers(pre, a, b, to) do
    [_, y, suffix] = Regex.run(~r/^(\d+)([A-Z]*)$/, b)
    each = for i <- String.to_integer(a)..String.to_integer(y)//1, do: pre ++ [to_string(i)]
    if suffix != "", do: each ++ [to], else: each
  end

  defp letters(pre, <<a>>, <<b>>), do: for(c <- a..b//1, do: pre ++ [<<c>>])
end
