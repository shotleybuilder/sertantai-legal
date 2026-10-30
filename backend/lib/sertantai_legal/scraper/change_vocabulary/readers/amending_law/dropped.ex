defmodule SertantaiLegal.Scraper.ChangeVocabulary.Readers.AmendingLaw.Dropped do
  @moduledoc """
  A whole substitution whose quote no longer makes some of the provision's
  numbers (CV-S09 round 7, the mirror of `Amendment.Reader.NewNumbers`):
  "For regulation 12A, substitute—" quoting (1)–(4) where SI 2008/1597
  reg.12A held (1)–(8) (SI 2026/867); "for regulation 9(5) substitute— (5)
  This regulation does not apply …" where (5) held (a)–(c) (NISR 2016/427
  on NISR 1999/304). The rows under the provision named that the quote
  doesn't make are repealed by the substituting law, the same day. Only
  rows the law holds (`known`); a row inserted after the substitution
  starts after it, so the repeal never reaches it. Pure.
  """

  alias SertantaiLegal.Scraper.Amendment.Rule
  alias SertantaiLegal.Scraper.LatRef

  @doc """
  `{source, row}` pairs: for each amending provision's whole substitution
  of a provision its quote makes, the held rows under it the quote leaves
  out (`known`: the amended law's rows, without version tags).
  """
  @spec rows([Rule.t()], MapSet.t() | nil) :: [{Rule.t(), String.t()}]
  def rows(_rules, nil), do: []

  def rows(rules, known) do
    rules
    |> Enum.group_by(&{&1.source.law, &1.source.ref, &1.amends})
    |> Enum.flat_map(fn {_, group} -> dropped(group, known) end)
  end

  defp dropped(group, known) do
    quoted =
      for %Rule{treatment: :quoted, level: :provision} = r <- group,
          t <- r.targets,
          into: MapSet.new(),
          do: t

    # the provisions substituted whole: the instruction's, else the quote's
    # top ("For regulation 12A, substitute— 12A …": one quoted rule)
    whole =
      for %Rule{operation: :substituted, level: :provision} = r <- group,
          r.treatment in [:instruction, :quoted],
          named <- r.targets,
          MapSet.member?(quoted, named),
          not Enum.any?(tl(LatRef.ancestors(named)), &MapSet.member?(quoted, &1)),
          uniq: true,
          do: {r, named}

    for {r, named} <- whole,
        row <- known,
        under?(row, named),
        not made?(row, named, quoted),
        uniq: true,
        do: {r, row}
  end

  defp under?(row, named), do: named in tl(LatRef.ancestors(row))

  # the quote makes it, or a provision holding it below the one named
  defp made?(row, named, quoted),
    do:
      row
      |> LatRef.ancestors()
      |> Enum.take_while(&(&1 != named))
      |> Enum.any?(&MapSet.member?(quoted, &1))
end
