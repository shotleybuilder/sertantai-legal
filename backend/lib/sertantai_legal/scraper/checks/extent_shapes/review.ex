defmodule SertantaiLegal.Scraper.Checks.ExtentShapes.Review do
  @moduledoc """
  Each item shape's bucket for review (CV-S05c step 2), ported from
  `review.py` (#192): from `items.tsv` and `verdicts.tsv`, every shape
  sorted into misread_plain or misread_qualified (some occurrence partial,
  missing, unread, unparsed or no_refs in a sentence read as a list),
  read_qualified (every occurrence read, the shape qualifying), in_unread,
  skip (plain, every occurrence read) or not_list. `run/2` writes what
  `review.py` wrote, byte for byte: `review.tsv` and `review.json`. Pure.
  """

  alias SertantaiLegal.Scraper.Checks.PyCompat

  @qual ~r/\b(other than|except|excluding|including|so far|insofar|in so far|relating|relates|together|with|but|save|apart|subject|WORDS|GAP|THIS_|THAT_|in )|^in\b/u
  @bad ~w(partial missing unread unparsed no_refs)
  @order %{
    "misread_plain" => 0,
    "misread_qualified" => 0.5,
    "read_qualified" => 1,
    "in_unread" => 2,
    "skip" => 3,
    "not_list" => 4
  }

  @doc "`items.tsv` and `verdicts.tsv` → `%{review:, summary:}` as iodata (`review.tsv`, `review.json`)."
  @spec run(String.t(), String.t()) :: %{review: iodata(), summary: iodata()}
  def run(items_tsv, verdicts_tsv) do
    items = items_tsv |> PyCompat.rows() |> List.to_tuple()

    rows =
      verdicts_tsv
      |> verdicts()
      |> Enum.reduce({%{}, []}, fn {ln, v}, acc -> add(acc, elem(items, ln - 1), v) end)
      |> then(fn {shapes, order} -> for s <- Enum.reverse(order), do: row(s, shapes[s]) end)
      |> Enum.sort_by(fn {b, n, _, s, _} -> {@order[b], -n, s} end)

    %{
      review: [
        "bucket\tcount\tlaws\tverdicts\tclasses\tshape\texamples\n" | Enum.map(rows, &line/1)
      ],
      summary: [PyCompat.json(summary(rows), 2)]
    }
  end

  # a dict by items_line in file order: a repeated line keeps its first place, its last value
  defp verdicts(tsv) do
    {order, by} =
      tsv
      |> PyCompat.dict_rows()
      |> Enum.reduce({[], %{}}, fn r, {order, by} ->
        ln = String.to_integer(r["items_line"])
        {if(Map.has_key?(by, ln), do: order, else: [ln | order]), Map.put(by, ln, r)}
      end)

    for ln <- Enum.reverse(order), do: {ln, by[ln]}
  end

  defp add({shapes, order}, [law, ref, cls, _kind, _letter, shape, _fine, text], v) do
    order = if Map.has_key?(shapes, shape), do: order, else: [shape | order]
    e = Map.get(shapes, shape, %{n: 0, laws: MapSet.new(), v: [], cls: [], ex: []})

    e = %{
      e
      | n: e.n + 1,
        laws: MapSet.put(e.laws, law),
        v: PyCompat.count(e.v, v["verdict"]),
        cls: PyCompat.count(e.cls, cls |> String.split(":") |> hd()),
        ex: example(e.ex, law, ref, v, text)
    }

    {Map.put(shapes, shape, e), order}
  end

  defp example(ex, law, ref, v, text) do
    verdict = v["verdict"]

    cond do
      verdict in @bad and length(ex) < 3 ->
        own = if v["own_refs"] in [nil, ""], do: "-", else: v["own_refs"]
        ex ++ ["#{law} #{ref} [#{verdict}: #{own}] #{PyCompat.slice(text, 200)}"]

      verdict not in @bad and ex == [] ->
        ex ++ ["#{law} #{ref} [#{verdict}] #{PyCompat.slice(text, 200)}"]

      true ->
        ex
    end
  end

  defp row(s, e), do: {bucket(s, e), e.n, MapSet.size(e.laws), s, e}

  defp bucket(s, e) do
    v = &PyCompat.get(e.v, &1)
    list? = PyCompat.get(e.cls, "list") > 0

    cond do
      Enum.any?(@bad, &(v.(&1) > 0)) and list? ->
        qualified(s, "misread_qualified", "misread_plain")

      v.("read") == e.n ->
        qualified(s, "read_qualified", "skip")

      PyCompat.get(e.cls, "unread") > 0 and not list? ->
        "in_unread"

      true ->
        rest_bucket(s, e, v)
    end
  end

  # read where it is a list statement at all, else not one, else misread
  defp rest_bucket(s, e, v) do
    cond do
      v.("read") > 0 and Enum.all?(e.v, fn {k, _} -> k in ["read", "no_list_statement"] end) ->
        qualified(s, "read_qualified", "skip")

      v.("no_list_statement") == e.n ->
        "not_list"

      true ->
        qualified(s, "misread_qualified", "misread_plain")
    end
  end

  defp qualified(s, yes, no), do: if(Regex.match?(@qual, s), do: yes, else: no)

  defp line({b, n, nl, s, e}) do
    counts = fn c ->
      Enum.map_join(PyCompat.most_common(c), "; ", fn {k, v} -> "#{k}×#{v}" end)
    end

    "#{b}\t#{n}\t#{nl}\t#{counts.(e.v)}\t#{counts.(e.cls)}\t#{s}\t#{Enum.join(e.ex, " || ")}\n"
  end

  defp summary(rows) do
    rows
    |> Enum.reduce([], fn {b, n, nl, _, _}, acc ->
      {_, c} = List.keyfind(acc, b, 0, {b, %{shapes: 0, items: 0, one: 0}})
      c = %{shapes: c.shapes + 1, items: c.items + n, one: c.one + if(nl == 1, do: 1, else: 0)}
      if List.keymember?(acc, b, 0), do: List.keystore(acc, b, 0, {b, c}), else: acc ++ [{b, c}]
    end)
    |> Enum.map(fn {b, c} ->
      {b, [{"shapes", c.shapes}, {"items", c.items}, {"one_law_shapes", c.one}]}
    end)
  end
end
