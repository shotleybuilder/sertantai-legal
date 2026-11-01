defmodule SertantaiLegal.Scraper.ChangeVocabulary.Label.Existence do
  @moduledoc """
  Whether a provision existed before a substitution made it (Jason
  2026-10-31, CV-06 round 1, R1: "evidence it existed"). A provision under
  a provision substituted whole, or one a substitution's quote makes,
  existed before only where a source shows it:

  - the text held predates the substitution (`valid`: its `dct:valid`;
    nil, the made text, predates every change) — its rows were there;
  - a dated change to it, or to a provision under it, before then (a
    commencement is no evidence: the law's clause is read down to every
    row, CV-S04) — unless the order names the row itself (`:named`: "Section
    10(2) to (4)", SI 1974/1439 on HSWA, before the 2008 substitution of
    s.10: CV-06 round 2, S1).

  Otherwise it begins at the substitution that first makes it (Jason
  2026-10-30: the quote alone is evidence it is new): CLP Art 37(9),
  first made by SI 2026/484, never under SI 2019/720's Art 37; HSWA
  s.11(1), its words changed in 2006, in force from 1974 under the 2008
  substitution of s.11.

  Pure.
  """

  alias SertantaiLegal.Scraper.ChangeVocabulary.Change
  alias SertantaiLegal.Scraper.LatRef

  @doc """
  The day `id` begins, from `born` (`Label.Start.start/2`): the latest
  whole substitution of a provision above it that nothing shows it
  predates, when later.
  """
  @spec born(String.t(), Date.t(), [Change.t()], [Change.t()], Date.t() | nil | :unknown) ::
          Date.t()
  def born(id, born, reaching, changes, valid) do
    reaching
    |> Enum.filter(&ancestor_substitution?(&1, id))
    |> Enum.map(& &1.resolved.date)
    |> Enum.filter(&(Date.compare(&1, born) == :gt and not existed?(id, &1, changes, valid)))
    |> Enum.max(Date, fn -> born end)
  end

  @doc """
  The day `id` begins (`born/5`) and `reaching` with the substitution above
  it that begins it read as its insertion: the text it begins with is that
  law's, in that law's territory (CV-06 round 2: CLP Art 52(1), begun by SI
  2019/720's Art 52 on 2020-12-31, is GB's by the Windsor rule, C8).
  """
  @spec begin(String.t(), Date.t(), [Change.t()], [Change.t()], Date.t() | nil | :unknown) ::
          {Date.t(), [Change.t()]}
  def begin(id, born, reaching, changes, valid) do
    begun = born(id, born, reaching, changes, valid)

    if Date.compare(begun, born) == :gt,
      do:
        {begun,
         Enum.map(reaching, fn c ->
           if ancestor_substitution?(c, id) and c.resolved.date == begun,
             do: %{c | resolved: %{c.resolved | operation: :inserted}},
             else: c
         end)},
      else: {begun, reaching}
  end

  @doc """
  `reaching` with each insertion of `id` that it predates (by the evidence
  above) read as a substitution of its text: the quote remade a provision
  that was there (NISR 1999/305 reg.11(2)(a), in the made text of 1999,
  "inserted" by the 2003 quote of reg.11(2)).
  """
  @spec reread(String.t(), [Change.t()], [Change.t()], Date.t() | nil | :unknown) :: [Change.t()]
  def reread(id, reaching, changes, valid) do
    Enum.map(reaching, fn c ->
      if c.target == id and c.resolved.operation in [:inserted, :added] and c.resolved.date != nil and
           existed?(id, c.resolved.date, changes, valid),
         do: %{c | resolved: %{c.resolved | operation: :substituted}},
         else: c
    end)
  end

  @doc "True when a source shows `id` held before `date`."
  @spec existed?(String.t(), Date.t(), [Change.t()], Date.t() | nil | :unknown) :: boolean()
  def existed?(_id, _date, _changes, nil), do: true

  def existed?(id, date, changes, valid) do
    (match?(%Date{}, valid) and Date.compare(valid, date) == :lt) or
      Enum.any?(changes, fn c ->
        # a quote's dropped rows (`AmendingLaw.Dropped`) are derived from
        # the quote, no source that the row was there (SI 2009/1348
        # reg.20(5)(b): CV-06 round 2)
        not String.ends_with?(c.key, "#dropped") and
          c.resolved.date != nil and on_it?(c, id) and
          (c.resolved.operation not in [:commenced, :applied, nil] or
             (c.target == id and Change.values(c, :commencement, :named) == [true])) and
          case Date.compare(c.resolved.date, date) do
            :lt ->
              true

            # a repeal of it that day: it was there to repeal (SI 1999/3242
            # reg.22(2), repealed the day reg.22 was substituted)
            # — unless it is inserted that day too (TCPA 1990 s.78(4BA))
            :eq ->
              c.resolved.operation in [:repealed, :repealed_in_part] and
                not inserted_on?(changes, id, date)

            :gt ->
              false
          end
      end)
  end

  @doc "A day's changes with its own whole repeal outranking a substitution or insertion of a provision holding it."
  @spec own_repeal_first([Change.t()], String.t()) :: [Change.t()]
  # its own whole repeal that day outranks a substitution of a provision
  # holding it: the substituting law repealed it (CV-06 round 1, R1: SI
  # 2003/2457 substituted reg.22 of SI 1999/3242 and repealed its (2))
  def own_repeal_first(day, id) do
    own_repeal? =
      Enum.any?(
        day,
        &(&1.target == id and &1.resolved.operation == :repealed and
            &1.resolved.level == :provision)
      )

    if own_repeal?,
      do:
        Enum.reject(
          day,
          &(&1.target != id and &1.resolved.operation in [:substituted, :inserted] and
              &1.resolved.level == :provision)
        ),
      else: day
  end

  defp inserted_on?(changes, id, date),
    do:
      Enum.any?(
        changes,
        &(&1.target == id and &1.resolved.operation in [:inserted, :added] and
            &1.resolved.date == date)
      )

  # on it or under it; or on a later item of the same list ("(b)" when it is
  # "(a)": SI 2009/1348 reg.32(1)(b), changed in 2011, shows a (1)(a) then)
  defp on_it?(c, id),
    do: c.target == id or id in LatRef.ancestors(c.target) or later_sibling?(c.target, id)

  defp later_sibling?(target, id) do
    with [_, parent, own] <- Regex.run(~r/^(.*)\(([^()]+)\)$/, id),
         [_, ^parent, other] <- Regex.run(~r/^(.*)\(([^()]+)\)$/, target) do
      later?(own, other)
    else
      _ -> false
    end
  end

  defp later?(a, b) do
    cond do
      a =~ ~r/^\d+$/ and b =~ ~r/^\d+$/ -> String.to_integer(b) > String.to_integer(a)
      a =~ ~r/^[a-hj-z]$/ and b =~ ~r/^[a-hj-z]$/ -> b > a
      true -> false
    end
  end

  defp ancestor_substitution?(c, id) do
    c.resolved.operation == :substituted and c.resolved.level == :provision and
      c.resolved.date != nil and c.target != id and c.target in LatRef.ancestors(id)
  end
end
