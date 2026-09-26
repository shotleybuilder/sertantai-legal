defmodule SertantaiLegal.Scraper.PdfBacklog.Transcript do
  @moduledoc """
  Pure parser for PDF-backlog transcripts: the text of a scanned-PDF-only law,
  written (by OCR, a vision model or a person) in a small line-based markup.
  `Clml.to_clml/1` turns the result into legislation.gov.uk-style XML so the
  standard `LatParser` produces the LAT rows.

  ## Markup (one paragraph per line; no hard wraps)

      ---                                  front matter (key: value)
      law_name: UK_uksi_1979_791
      extent: E+W+S
      ---
      <!-- comment -->                     ignored
      ## Citation and extent               heading (body: the next regulation's
                                           heading; schedule: a heading row)
      1.—(1) Text                          regulation 1 with paragraph (1)
      2. Text                              regulation 2
      (2) Text                             numbered paragraph
      (a) Text                             lettered item (under the open
                                           paragraph, else the regulation)
      Unmarked text                        continues the open provision; after
                                           lettered items, trailing text of
                                           their parent
      > "quoted text"                      inserted/quoted text: kept in the
                                           open provision, never parsed
      # SIGNED                             signature block (lines are text)
      # SCHEDULE 2: Title                  schedule; its numbered lines are
                                           schedule paragraphs

  Write `[?]` where a reading is uncertain; `qa/1` reports it.
  """

  @enforce_keys [:meta, :body, :signed, :schedules]
  defstruct [:meta, :body, :signed, :schedules]

  @type item :: map()
  @type t :: %__MODULE__{
          meta: %{optional(String.t()) => String.t()},
          body: [item()],
          signed: [String.t()],
          schedules: [%{number: String.t(), title: String.t() | nil, items: [item()]}]
        }

  @p1_p2 ~r/^(\d+[A-Z]?)\.\s*[—–-]+\s*\((\d+[A-Z]?)\)\s*(.*)$/u
  @p1 ~r/^(\d+[A-Z]?)\.\s+(.*)$/u
  @p2 ~r/^\((\d+[A-Z]?)\)\s*(.*)$/u
  @p3 ~r/^\(([a-z]{1,2})\)\s*(.*)$/u
  @schedule ~r/^#\s+SCHEDULE\s+(\d+[A-Z]?)\s*(?::\s*(.*))?$/iu

  @doc "Parse a transcript. Errors name the offending line."
  @spec parse(String.t()) :: {:ok, t()} | {:error, String.t()}
  def parse(text) do
    {meta, lines} = split_front_matter(text)

    with {:ok, sections} <- sectionise(lines),
         {:ok, t} <- build(meta, sections) do
      if t.body == [] and Enum.all?(t.schedules, &(&1.items == [])),
        do: {:error, "no provisions found"},
        else: {:ok, t}
    end
  end

  # ── Front matter and sections ──────────────────────────────────

  defp split_front_matter(text) do
    lines = text |> String.split("\n") |> Enum.with_index(1)

    case lines do
      [{"---", _} | rest] ->
        {fm, [_close | body]} = Enum.split_while(rest, fn {l, _} -> String.trim(l) != "---" end)

        meta =
          for {l, _} <- fm,
              [k, v] <- [String.split(l, ":", parts: 2)],
              into: %{},
              do: {String.trim(k), String.trim(v)}

        {meta, body}

      _ ->
        {%{}, lines}
    end
  end

  # Split lines into [{:body | :signed | {:schedule, n, title}, [{line, no}]}]
  defp sectionise(lines) do
    lines
    |> Enum.map(fn {l, n} -> {String.trim(l), n} end)
    |> Enum.reject(fn {l, _} -> l == "" or comment?(l) end)
    |> Enum.reduce_while({:ok, [{:body, []}]}, fn {l, n}, {:ok, [{sec, acc} | done]} ->
      cond do
        String.starts_with?(l, "## ") or not String.starts_with?(l, "#") ->
          {:cont, {:ok, [{sec, [{l, n} | acc]} | done]}}

        Regex.match?(~r/^#\s+SIGNED\s*$/i, l) ->
          {:cont, {:ok, [{:signed, []}, {sec, acc} | done]}}

        m = Regex.run(@schedule, l) ->
          [_, num | title] = m
          sch = {:schedule, num, blank_to_nil(List.first(title))}
          {:cont, {:ok, [{sch, []}, {sec, acc} | done]}}

        true ->
          {:halt, {:error, "line #{n}: unknown section directive #{inspect(l)}"}}
      end
    end)
    |> case do
      {:ok, secs} ->
        {:ok, secs |> Enum.map(fn {s, acc} -> {s, Enum.reverse(acc)} end) |> Enum.reverse()}

      error ->
        error
    end
  end

  defp comment?(l), do: String.starts_with?(l, "<!--") and String.ends_with?(l, "-->")

  defp build(meta, sections) do
    Enum.reduce_while(
      sections,
      {:ok, %__MODULE__{meta: meta, body: [], signed: [], schedules: []}},
      fn
        {:body, lines}, {:ok, t} ->
          case items(lines, :body) do
            {:ok, items} -> {:cont, {:ok, %{t | body: t.body ++ items}}}
            error -> {:halt, error}
          end

        {:signed, lines}, {:ok, t} ->
          {:cont, {:ok, %{t | signed: t.signed ++ Enum.map(lines, &elem(&1, 0))}}}

        {{:schedule, num, title}, lines}, {:ok, t} ->
          case items(lines, :schedule) do
            {:ok, items} ->
              sch = %{number: num, title: title, items: items}
              {:cont, {:ok, %{t | schedules: t.schedules ++ [sch]}}}

            error ->
              {:halt, error}
          end
      end
    )
  end

  # ── Provision tree ─────────────────────────────────────────────

  # State: done items (reversed), open p1/p2/p3, pending body heading.
  defp items(lines, where) do
    init = %{done: [], p1: nil, p2: nil, p3: nil, heading: nil, where: where}

    lines
    |> Enum.reduce_while({:ok, init}, fn {l, n}, {:ok, st} ->
      case step(classify(l), n, st) do
        {:ok, st} -> {:cont, {:ok, st}}
        {:error, why} -> {:halt, {:error, "line #{n}: #{why}"}}
      end
    end)
    |> case do
      {:ok, st} ->
        {:ok, st |> close_p1() |> flush_heading() |> Map.fetch!(:done) |> Enum.reverse()}

      error ->
        error
    end
  end

  defp classify("## " <> title), do: {:heading, String.trim(title)}
  defp classify("> " <> text), do: {:quote, text}
  defp classify(">" <> text), do: {:quote, String.trim(text)}

  defp classify(l) do
    cond do
      m = Regex.run(@p1_p2, l) ->
        [_, n1, n2, text] = m
        {:p1_p2, n1, n2, text}

      m = Regex.run(@p1, l) ->
        [_, n1, text] = m
        {:p1, n1, text}

      m = Regex.run(@p3, l) ->
        [_, a, text] = m
        {:p3, a, text}

      m = Regex.run(@p2, l) ->
        [_, n2, text] = m
        {:p2, n2, text}

      true ->
        {:cont, l}
    end
  end

  defp step({:heading, title}, _n, %{where: :body} = st),
    do: {:ok, st |> close_p1() |> flush_heading() |> Map.put(:heading, title)}

  defp step({:heading, title}, _n, st),
    do: {:ok, st |> close_p1() |> push(%{type: :heading, title: title})}

  defp step({:p1_p2, n1, n2, text}, n, st) do
    {:ok, st} = step({:p1, n1, ""}, n, st)
    step({:p2, n2, text}, n, st)
  end

  defp step({:p1, num, text}, _n, st) do
    st = close_p1(st)

    p1 = %{
      type: :p1,
      num: num,
      heading: st.heading,
      text: texts(text),
      children: [],
      trailing: []
    }

    {:ok, %{st | p1: p1, heading: nil}}
  end

  defp step({:p2, _num, _text}, _n, %{p1: nil}), do: {:error, "paragraph before any regulation"}

  defp step({:p2, num, text}, _n, st) do
    st = close_p2(st)
    {:ok, %{st | p2: %{type: :p2, num: num, text: texts(text), children: [], trailing: []}}}
  end

  defp step({:p3, _a, _text}, _n, %{p1: nil}), do: {:error, "lettered item with no parent"}

  defp step({:p3, a, text}, _n, st) do
    st = close_p3(st)
    {:ok, %{st | p3: %{type: :p3, num: a, text: texts(text)}}}
  end

  defp step({:quote, text}, _n, st), do: append_text(st, text)

  defp step({:cont, text}, _n, %{p3: p3} = st) when p3 != nil do
    st = close_p3(st)
    append_trailing(st, text)
  end

  defp step({:cont, text}, _n, st), do: append_text(st, text)

  defp append_text(%{p3: p3} = st, t) when p3 != nil, do: {:ok, %{st | p3: add_text(p3, t)}}
  defp append_text(%{p2: p2} = st, t) when p2 != nil, do: {:ok, %{st | p2: add_text(p2, t)}}
  defp append_text(%{p1: p1} = st, t) when p1 != nil, do: {:ok, %{st | p1: add_text(p1, t)}}
  defp append_text(_st, _t), do: {:error, "text outside any provision"}

  defp append_trailing(%{p2: p2} = st, t) when p2 != nil,
    do: {:ok, %{st | p2: %{p2 | trailing: p2.trailing ++ [t]}}}

  defp append_trailing(%{p1: p1} = st, t),
    do: {:ok, %{st | p1: %{p1 | trailing: p1.trailing ++ [t]}}}

  defp add_text(item, t), do: %{item | text: item.text ++ [t]}

  defp texts(""), do: []
  defp texts(t), do: [t]

  defp close_p3(%{p3: nil} = st), do: st

  defp close_p3(%{p3: p3, p2: p2} = st) when p2 != nil,
    do: %{st | p2: %{p2 | children: p2.children ++ [p3]}, p3: nil}

  defp close_p3(%{p3: p3, p1: p1} = st),
    do: %{st | p1: %{p1 | children: p1.children ++ [p3]}, p3: nil}

  defp close_p2(st) do
    case close_p3(st) do
      %{p2: nil} = st -> st
      %{p2: p2, p1: p1} = st -> %{st | p1: %{p1 | children: p1.children ++ [p2]}, p2: nil}
    end
  end

  defp close_p1(st) do
    case close_p2(st) do
      %{p1: nil} = st -> st
      %{p1: p1} = st -> %{push(st, p1) | p1: nil}
    end
  end

  defp flush_heading(%{heading: nil} = st), do: st

  defp flush_heading(%{heading: h} = st),
    do: %{push(st, %{type: :heading, title: h}) | heading: nil}

  defp push(st, item), do: %{st | done: [item | st.done]}

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(s), do: if(String.trim(s) == "", do: nil, else: String.trim(s))

  # ── QA ─────────────────────────────────────────────────────────

  @doc """
  Quality warnings: numbering gaps (regulations, paragraphs, lettered items)
  and `[?]` uncertain readings. Gaps can be genuine (e.g. revoked provisions),
  so these are warnings for the reviewer, not errors.
  """
  @spec qa(t()) :: [String.t()]
  def qa(%__MODULE__{} = t) do
    scopes = [
      {"body", "reg.", t.body}
      | Enum.map(t.schedules, &{"sch.#{&1.number}", "sch.#{&1.number}.reg.", &1.items})
    ]

    gaps =
      Enum.flat_map(scopes, fn {scope, prefix, items} ->
        p1s = Enum.filter(items, &(&1.type == :p1))
        gap_warnings(scope, "regulation", p1s) ++ Enum.flat_map(p1s, &p1_gaps(prefix, &1))
      end)

    uncertain =
      Enum.flat_map(scopes, fn {_scope, prefix, items} ->
        items |> Enum.filter(&(&1.type == :p1)) |> Enum.flat_map(&uncertain(prefix <> &1.num, &1))
      end)

    gaps ++ uncertain
  end

  defp p1_gaps(prefix, p1) do
    label = prefix <> p1.num
    {p2s, p3s} = Enum.split_with(p1.children, &(&1.type == :p2))

    gap_warnings(label, "paragraph", p2s) ++
      gap_warnings(label, "item", p3s) ++
      Enum.flat_map(p2s, &gap_warnings("#{label}(#{&1.num})", "item", &1.children))
  end

  # "body: regulation 3 follows 1", "reg.1: paragraph (3) follows (1)"
  defp gap_warnings(scope, noun, items) do
    fmt = fn n -> if noun == "regulation", do: n, else: "(#{n})" end

    items
    |> Enum.map(& &1.num)
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reject(fn [a, b] -> next?(a, b) end)
    |> Enum.map(fn [a, b] -> "#{scope}: #{noun} #{fmt.(b)} follows #{fmt.(a)}" end)
  end

  defp next?(a, b) do
    case {Integer.parse(a), Integer.parse(b)} do
      {{x, ""}, {y, ""}} -> y == x + 1
      {{_, ""}, _} -> true
      {:error, :error} -> letter_next?(a, b)
      _ -> true
    end
  end

  defp letter_next?(<<x>>, <<y>>), do: y == x + 1
  defp letter_next?(_, _), do: true

  defp uncertain(label, item) do
    own =
      if Enum.any?(item.text ++ Map.get(item, :trailing, []), &String.contains?(&1, "[?]")),
        do: ["#{label}: uncertain reading [?]"],
        else: []

    own ++ Enum.flat_map(Map.get(item, :children, []), &uncertain("#{label}(#{&1.num})", &1))
  end
end
