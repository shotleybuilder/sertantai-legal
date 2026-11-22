defmodule SertantaiLegal.Scraper.Commencement.Authority do
  @moduledoc """
  An Act's commencing authority for each place (Decision 10, Jason
  2026-11-22): who may appoint the day a provision comes into force, and
  where. The Water Act 2003 s.105(6) table ("Sections 58, 69, … and 86 |
  The Secretary of State, in relation to England; the Assembly, in relation
  to Wales."; "Section 67 | The Assembly …"), and the Planning Act 2008
  s.241(3)–(4) list ("the provisions listed in subsection (4) come into
  force on such day as may be appointed by order made by— (a) the Welsh
  Ministers, in relation to Wales; (b) the Secretary of State, in relation
  to England"). An order its authority makes brings a provision in where
  that authority may, though the order names no place. Pure: the Act's
  rows come in.
  """

  alias SertantaiLegal.Scraper.Commencement.{Order.Territory, TextRefs}
  alias SertantaiLegal.Scraper.LatRef

  @type maker :: :uk | :wales
  @type t :: [%{refs: [String.t()], by: %{optional(maker()) => String.t() | nil}}]

  @doc "The authorities the Act's rows (`{section_id, text}`, in document order) state."
  @spec read([{String.t(), String.t() | nil}]) :: t()
  def read(rows) do
    rows = for {id, text} <- rows, is_binary(text), do: {bare(id), text}
    Enum.flat_map(rows, &table/1) ++ lists(rows)
  end

  @doc """
  Where an order `maker` makes brings in `scope`: `{:ok, place}` (nil for
  everywhere) where one authority covers every ref of it, else `:none`.
  """
  @spec territory(t(), term(), maker() | nil) :: {:ok, String.t() | nil} | :none
  def territory(authorities, scope, maker) when is_list(scope) and maker != nil do
    case scope |> Enum.map(&place(authorities, &1, maker)) |> Enum.uniq() do
      [{:ok, _} = place] -> place
      _ -> :none
    end
  end

  def territory(_authorities, _scope, _maker), do: :none

  # the place one ref's authority gives, or :none
  defp place(authorities, ref, maker) do
    case Enum.find(authorities, &(Map.has_key?(&1.by, maker) and covers?(&1.refs, ref))) do
      nil -> :none
      a -> {:ok, a.by[maker]}
    end
  end

  @doc """
  `scope` split by where an order `maker` makes brings each part in:
  `[{refs, except, place}]`, `place` `:default` where no authority speaks
  (the order's own default applies). A range holding a provision with an
  authority of its own leaves it out, the provision its own part ("sections
  81 to 83" with s.81 England's: SI 2004/641). `[{scope, [], :default}]`
  when none speaks.
  """
  @spec split(t(), term(), maker() | nil) :: [{term(), [String.t()], String.t() | nil | :default}]
  def split(authorities, scope, maker) when is_list(scope) and maker != nil do
    own = for a <- authorities, Map.has_key?(a.by, maker), r <- a.refs, do: {r, a.by[maker]}

    {{refs, except}, placed} =
      Enum.reduce(scope, {{[], []}, []}, &split_ref(&1, &2, authorities, maker, own))

    by_place =
      placed
      |> Enum.reverse()
      |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))
      |> Enum.map(fn {place, refs} -> {refs, [], place} end)

    if refs == [], do: by_place, else: [{refs, except, :default} | by_place]
  end

  def split(_authorities, scope, _maker), do: [{scope, [], :default}]

  defp split_ref(ref, {{refs, except}, placed}, authorities, maker, own) do
    case place(authorities, ref, maker) do
      {:ok, place} ->
        {{refs, except}, [{ref, place} | placed]}

      :none ->
        inside = inside(ref, own)
        {{refs ++ [ref], except ++ Enum.map(inside, &elem(&1, 0))}, inside ++ placed}
    end
  end

  # a range's provisions with an authority of their own
  defp inside(ref, own) do
    if String.contains?(ref, ".."),
      do: for({r, place} <- own, r != ref, LatRef.covers?(ref, r), do: {r, place}),
      else: []
  end

  defp covers?(refs, ref),
    do: Enum.any?(refs, fn r -> Enum.any?(LatRef.ancestors(ref), &LatRef.covers?(r, &1)) end)

  defp bare(id), do: id |> String.split(":", parts: 2) |> List.last()

  # ── a table: "<provisions> | <authority>; <provisions> | <authority>." ──

  defp table({_id, text}) do
    cells = String.split(text, ~r/\s*\|\s*/u)

    if length(cells) > 1 do
      cells
      |> Enum.chunk_every(2, 1, :discard)
      |> Enum.flat_map(fn [left, right] -> entry(tail(left), head(right)) end)
    else
      []
    end
  end

  # a cell's last row's provisions; the next cell's authority up to them
  @row_start ~r/;\s+(?=(?:Sections?|Schedules?|Parts?|Paragraphs?)\s+\S)/u

  defp tail(cell), do: cell |> String.split(@row_start) |> List.last()
  defp head(cell), do: cell |> String.split(@row_start) |> hd()

  defp entry(provisions, authority) do
    with false <- authority =~ ~r/^\W*as\s+respects\b/i,
         [_ | _] = refs <- TextRefs.refs(provisions, nil),
         by when by != %{} <- makers(String.split(authority, ~r/;\s*/u)) do
      [%{refs: refs, by: by}]
    else
      _ -> []
    end
  end

  # each clause's maker, the first it names, with the place it names
  defp makers(clauses) do
    for clause <- clauses, maker = maker(clause), into: %{}, do: {maker, Territory.of(clause)}
  end

  @maker ~r/\b(Secretary\s+of\s+State|(?:National\s+)?Assembly|Welsh\s+Ministers)\b/u

  defp maker(clause) do
    case Regex.run(@maker, clause) do
      [_, "Secretary" <> _] -> :uk
      [_, _] -> :wales
      nil -> nil
    end
  end

  # ── a list: "the provisions listed in subsection (4) … made by— (a) …" ──

  @listed ~r/\bthe\s+provisions\s+(?:listed|specified|mentioned)\s+in\s+subsection\s+(\([0-9A-Za-z]+\))\s+comes?\s+into\s+force\s+on\s+such\s+day\s+as\s+may\s+be\s+appointed\s+by\s+order\s+made\s+by\W*$/iu

  defp lists(rows) do
    for {id, text} <- rows,
        [_, sub] <- [Regex.run(@listed, text)],
        entry <- list(rows, id, sub),
        do: entry
  end

  defp list(rows, id, sub) do
    by = rows |> children(id) |> Enum.map(&elem(&1, 1)) |> makers()
    listed = String.replace(id, ~r/\([0-9A-Za-z]+\)$/, "") <> sub

    refs =
      rows
      |> children(listed)
      |> Enum.reject(fn {item, _} -> other_laws?(rows, item) end)
      |> Enum.flat_map(fn {_, text} -> TextRefs.refs(text, nil) end)

    if refs != [] and map_size(by) > 1, do: [%{refs: refs, by: by}], else: []
  end

  defp children(rows, id),
    do: Enum.filter(rows, fn {r, _} -> String.starts_with?(r, id <> "(") end)

  # "(d) the repeals in— (i) TCPA 1990 …": another law's provisions
  defp other_laws?(rows, item) do
    Enum.any?(rows, fn {r, text} ->
      (r == item or String.starts_with?(item, r <> "(")) and text =~ ~r/^\W*the\s+repeals\b/i
    end)
  end
end
