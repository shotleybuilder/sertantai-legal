defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.Markup.JoinedSectionRef do
  @moduledoc """
  The provisions a note piece's `SectionRef` names where legislation.gov.uk
  joins sibling provisions in one id.

  "ss. 86(2)(c)(5)(8)" (the Income Tax (Earnings and Pensions) Act 2003
  s.446R(4), by the Finance Act 2004) is marked up as one piece,
  `section-86-2-c-5-8`: s.86(2)(c), s.86(5) and s.86(8), three provisions
  and no one provision s.86(2)(c)(5)(8). The piece's words join the parts
  as the id does, with no comma, so the split is read from the parts'
  forms, as the amending laws' own ids nest (checked against the ids of
  the 1,970 amending laws held: 6,372 joined pieces, 47,220 pieces in
  all):

  - a number climbs back to the number before it: "(2)(c)(5)" is (2)(c)
    and (5); "(A1)" and "(5A)" are numbers;
  - a part after a part of its own form stands beside it: "(c)(d)",
    "(iii)(iv)", "(ddd)(jjj)";
  - a part of a lower form is under the part before it: "(1)(a)",
    "(a)(ii)", "(c)(i)", "(ii)(aa)", "(aa)(iii)";
  - a Schedule written after a provision is its own piece: "s. 22(3) Sch.
    9 para. 3(1)" under `section-22-3-schedule-9-paragraph-3-1`.

  Where the forms do not settle the split, the piece is carried as given,
  one joined ref (the source's own id: it is a real id of the amending law
  for 151 of 433 such pieces checked, and a joined ref that names nothing
  matches nothing): a letter then a doubled letter ("art. 3(y)(aa)"
  beside, "31(14)(g)(bb)" under), "(i)", "(v)" or "(x)" then a letter
  ("art. 4(i)(j)" letters, "(a)(i)(b)(ii)" a numeral), "(a)(i)(viii)"
  ((a)(i) and (a)(viii), or (a) and (i)(viii)), a roman numeral then a
  letter, "(i)(v)", "(gg)(ii)", the same part twice ("(c)(c)"; "(i)(i)" is
  the letter with the numeral under it), a number with
  no number before it ("s. 171(b)(2)"). An id of any other shape is
  returned as it is. Pure.
  """

  @head ~r/^(schedule(?:-(?!part-|paragraph-)[^-]+)?(?:-part-[^-]+)?-paragraph-[^-]+|(?:section|regulation|article|rule)-[^-]+)((?:-[^-]+)+)$/
  @kind_words ~w(schedule part paragraph section regulation article rule chapter)

  # the forms a part under the part before it may take
  @under MapSet.new([
           {:letter, :either},
           {:letter, :roman},
           {:letter, :roman_or_doubled},
           {:either, :roman},
           {:either, :doubled},
           {:roman, :doubled},
           {:roman_or_doubled, :doubled},
           {:doubled, :roman},
           {:doubled, :either}
         ])
  @beside MapSet.new([
            {:letter, :letter},
            {:roman, :roman},
            {:doubled, :doubled},
            {:capital, :capital}
          ])

  @doc """
  The SectionRefs of the provisions a SectionRef names, in order:
  `"section-86-2-c-5-8"` → `["section-86-2-c", "section-86-5",
  "section-86-8"]`; a nesting, itself (`"regulation-8-4-a-ii"`); a split
  the forms do not settle, itself (`"regulation-5-a-aa"`).
  """
  @spec pieces(String.t()) :: [String.t()]
  def pieces(section_ref) do
    section_ref |> apart() |> Enum.flat_map(&split/1)
  end

  # a Schedule joined after a provision is its own id
  defp apart(section_ref), do: String.split(section_ref, ~r/(?<=.)-(?=schedule(?:-|$))/)

  defp split(id) do
    with [_, head, rest] <- Regex.run(@head, id),
         parts = String.split(rest, "-", trim: true),
         false <- Enum.any?(parts, &(&1 in @kind_words)) do
      parts |> walk() |> Enum.map(&Enum.join([head | &1], "-"))
    else
      _ -> [id]
    end
  end

  # the paths the parts name: the path so far is a provision of its own
  # whenever a part stands in place of one of its parts
  defp walk([first | parts] = all) do
    parts
    |> Enum.reduce_while({[first], []}, fn part, {path, done} ->
      case place(path, part) do
        :unknown -> {:halt, :unknown}
        :under -> {:cont, {path ++ [part], done}}
        kept -> {:cont, {kept ++ [part], [path | done]}}
      end
    end)
    |> named(all)
  end

  # an unsettled split: the parts as given, one path
  defp named(:unknown, all), do: [all]
  defp named({path, done}, _all), do: Enum.reverse([path | done])

  # where a part stands: under the path, or in place of one of its parts
  # (the parts of the path kept above it)
  defp place(path, part), do: placed(path, List.last(path), form(part), part)

  defp placed(path, _last, :number, _part), do: above_number(path)
  # "(4)(i)(i)": the letter, and the roman numeral under it; "(f)(i)(i)":
  # (f) and (i)(i), never one provision
  defp placed(path, same, :either, same), do: if(letter_above?(path), do: :unknown, else: :under)
  defp placed(_path, same, _form, same), do: :unknown

  defp placed(path, last, form, _part) do
    pair = {form(last), form}

    cond do
      numeral_under_letter?(path, pair) -> :unknown
      under?(pair) -> :under
      MapSet.member?(@beside, pair) -> Enum.drop(path, -1)
      true -> :unknown
    end
  end

  # "(a)(i)(viii)": (a)(i) and (a)(viii), or (a) and (i)(viii)
  defp numeral_under_letter?(path, {:either, :roman}), do: letter_above?(path)
  defp numeral_under_letter?(_path, _pair), do: false

  # the part above the path's last is a letter
  defp letter_above?(path), do: path |> Enum.at(-2) |> then(&(&1 != nil and form(&1) == :letter))

  defp under?({:number, _form}), do: true
  defp under?({above, :capital}), do: above != :capital
  defp under?(pair), do: MapSet.member?(@under, pair)

  defp above_number(path) do
    case Enum.split_while(path, &(form(&1) != :number)) do
      {before, [_ | _]} -> before
      {_all, []} -> :unknown
    end
  end

  # "4", "5A" and "A1" are numbers, "B" a capital, "i", "v" and "x" a
  # letter or a roman numeral, "ii" and "xx" a roman numeral or a doubled
  # letter, "iii" and "xlvii" roman numerals, "aa" and "ddd" doubled
  # letters, "c" a letter, as an inserted "ca", "za" or "z14" is
  defp form(part) do
    cond do
      part =~ ~r/^(?:\d|[A-Z]+\d)/ -> :number
      part =~ ~r/^[A-Z]/ -> :capital
      part in ~w(i v x) -> :either
      part in ~w(ii xx) -> :roman_or_doubled
      part =~ ~r/^([a-z])\1+$/ and part not in ~w(iii xxx) -> :doubled
      part =~ ~r/^[ivxlc]{2,}$/ -> :roman
      true -> :letter
    end
  end
end
