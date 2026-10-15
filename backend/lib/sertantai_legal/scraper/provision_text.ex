defmodule SertantaiLegal.Scraper.ProvisionText do
  @moduledoc """
  The grammar of a changes-feed effect's `AffectedProvisions` text
  (lat-refactor LR-29): legislation.gov.uk's own statement of what an
  effect changed, at its true granularity ("s. 27ZA and cross-heading",
  "Pt. 2 Ch. 3", "s. 33(1)(e)-(h)"). Its structured refs can be coarser (a
  container) or truncated (a range's first id), so `EffectTarget` lands an
  effect where this text says. Pure; text it can't read is `:error`, never a
  guess.

  Designators:
  - `{:provision, kind, number, path, to}` — "s. 27ZA(1)(a)": `kind`
    section | regulation | article | rule, `path` the brackets as written,
    `to` the end of a bracket range ("(e)-(h)") or nil
  - `{:range, kind, first, last}` — "ss. 11C-11H", "s. 50 - 55"
  - `{:part, part, chapter | nil}`, `{:schedule, schedule, paragraph | nil}`
  - `{:element, kind, number}` / `{:part_element, part, chapter | nil}` — a
    heading, sidenote or title: that element alone
  - `:heading` — "cross-heading", "s. 81 cross-heading": the heading element
    the refs name, not what sits under it
  - `:whole` — "Act", "Regulations": the whole instrument
  """

  @type designator ::
          {:provision, String.t(), String.t(), [String.t()], String.t() | nil}
          | {:range, String.t(), String.t(), String.t()}
          | {:part, String.t(), String.t() | nil}
          | {:schedule, String.t(), String.t() | nil}
          | {:element, String.t(), String.t()}
          | {:part_element, String.t(), String.t() | nil}
          | :heading
          | :whole

  @kinds %{
    "s" => "section",
    "ss" => "section",
    "reg" => "regulation",
    "regs" => "regulation",
    "art" => "article",
    "arts" => "article",
    "rule" => "rule",
    "rules" => "rule",
    "r" => "rule"
  }

  @number "[0-9]+[A-Z]*|[A-Z]+[0-9]*"
  @provision ~r/^(ss?|regs?|arts?|rules?|r)\.?\s?(.+?)(?:\s(cross-heading|heading|sidenote|title))?$/
  @whole ~r/^(?:the\s)?(?:whole\s)?(?:Act|Measure|Order|Regulations|Rules|Scheme|instrument)$/i

  @doc "The designators the text names, or `:error` when any part of it can't be read."
  @spec parse(String.t() | nil) :: {:ok, [designator()]} | :error
  def parse(nil), do: :error

  def parse(text) do
    items =
      text
      |> String.replace(~r/\s+/u, " ")
      |> String.trim()
      |> String.replace(~r/\band\b/, ",")
      |> String.split(",")
      |> Enum.map(&String.trim/1)
      |> Enum.reject(&(&1 == ""))

    # a bare number continues the last item's kind ("s. 5, 6 and 9")
    {parsed, _} =
      Enum.map_reduce(items, nil, fn it, prefix ->
        it = if prefix && it =~ ~r/^[0-9(]/, do: prefix <> " " <> it, else: it

        prefix =
          case Regex.run(~r/^(ss?|regs?|arts?|rules?|r)\.?(?=\s?[0-9])/, it) do
            [p, _] -> p
            nil -> nil
          end

        {item(it), prefix}
      end)

    if items != [] and Enum.all?(parsed, &(&1 != :error)),
      do: {:ok, Enum.concat(parsed)},
      else: :error
  end

  defp item(item) do
    item =
      item
      |> String.replace(~r/\s+defn\..*$/, "")
      |> String.replace(~r/\s+\((?:Pt|Ch|Sch|with|as|for|in|so)\b[^)]*\)$/i, "")
      |> String.replace(~r/\s*[-–]\s*/u, "-")

    cond do
      item =~ @whole ->
        [:whole]

      item =~ ~r/^(?:cross-heading|heading)$/i ->
        [:heading]

      m = Regex.run(@provision, item) ->
        provision_item(m)

      m = Regex.run(~r/^Pt\.\s?(#{@number})(?:\sCh\.\s?(#{@number}))?(\sheading)?$/, item) ->
        part(m)

      m = Regex.run(~r/^Sch\.\s?(#{@number})(?:\spara\.\s?(#{@number}))?$/, item) ->
        schedule(m)

      true ->
        :error
    end
  end

  defp provision_item([_, k, body | tail]) do
    kind = @kinds[String.downcase(k)]

    case List.first(tail) do
      "cross-heading" -> [:heading]
      t when t in ["heading", "sidenote", "title"] -> element(kind, body)
      _ -> provisions(kind, body)
    end
  end

  defp element(kind, body) do
    if body =~ ~r/^(#{@number})$/, do: [{:element, kind, body}], else: :error
  end

  # "27I 27J", "32-37 39", "12(8) (8A)" (a bracket after a space continues
  # the last provision)
  defp provisions(kind, body) do
    {items, _} =
      body
      |> String.split(" ", trim: true)
      |> Enum.map_reduce(nil, fn tok, last ->
        cond do
          String.starts_with?(tok, "(") and last != nil -> {one(kind, last <> tok), last}
          m = Regex.run(~r/^(#{@number})-(#{@number})$/, tok) -> {range(kind, m), nil}
          true -> {one(kind, tok), tok |> String.split("(") |> hd()}
        end
      end)

    if Enum.all?(items, &(&1 != :error)), do: items, else: :error
  end

  defp range(kind, [_, a, b]), do: {:range, kind, a, b}

  defp one(kind, tok) do
    case Regex.run(~r/^(#{@number})((?:\([^()\s]+\))*)(?:-\(([^()\s]+)\))?$/, tok) do
      [_, n] -> {:provision, kind, n, [], nil}
      [_, n, path] -> {:provision, kind, n, brackets(path), nil}
      [_, n, path, to] -> {:provision, kind, n, brackets(path), to}
      nil -> :error
    end
  end

  defp brackets(path),
    do: ~r/\(([^()]+)\)/ |> Regex.scan(path, capture: :all_but_first) |> List.flatten()

  defp part([_, p]), do: [{:part, p, nil}]
  defp part([_, p, ""]), do: [{:part, p, nil}]
  defp part([_, p, c]), do: [{:part, p, c}]
  defp part([_, p, c, _heading]), do: [{:part_element, p, blank(c)}]

  defp schedule([_, s]), do: [{:schedule, s, nil}]
  defp schedule([_, s, para]), do: [{:schedule, s, para}]

  defp blank(""), do: nil
  defp blank(s), do: s
end
