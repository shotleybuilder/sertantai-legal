defmodule SertantaiLegal.Scraper.LatParser.Ids do
  @moduledoc """
  Provision numbers and headings from CLML for the LAT parser (LR-04):
  Pnumbers, Part / Chapter / Schedule Numbers (with any dashed heading),
  Titles (the `title` column and heading text), a Pblock's first P1
  number, and whether a P1's single P2 is a structural wrapper. Pure.
  """

  import SweetXml

  alias SertantaiLegal.Scraper.LatParser.Xml
  alias SertantaiLegal.Scraper.LatSegments

  @doc """
  A P1's P2 children are a structural wrapper: exactly one P2, numbered as
  the P1 — a container, not a true subsection.
  """
  @spec p2_wrapper?(tuple(), String.t() | nil) :: boolean()
  def p2_wrapper?(p1_node, provision) do
    p2_numbers =
      p1_node
      |> xpath(~x".//P2"l)
      |> Enum.map(&pnumber/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    p2_numbers == [provision]
  end

  @doc "A provision's Pnumber (through change markup; an EU \"6.\" is 6), nil when none."
  @spec pnumber(tuple()) :: String.t() | nil
  def pnumber(node) do
    # descendant::text() reaches through nested Addition/Repeal/Substitution
    # wrappers in document order (xmerl's //text() puts direct text first)
    case xpath(node, ~x"./Pnumber/descendant::text()"ls) do
      nil ->
        nil

      texts ->
        texts
        |> Enum.map(&to_string/1)
        |> Enum.join("")
        |> String.trim()
        # "6." (EU paragraph numbering) is number 6: no "(6.)" in ids
        |> String.trim_trailing(".")
        |> case do
          "" -> nil
          v -> v
        end
    end
  end

  @doc ~s[A Number's number without its prefix word ("Part III.— …" → "III").]
  @spec number(tuple(), String.t()) :: String.t() | nil
  def number(node, prefix), do: node |> number_parts(prefix) |> elem(0)

  # A Number's number and any heading joined to it by a dash: "Part III.—
  # Administration of Law" → {"III", "Administration of Law"}; "PART 3 —" →
  # {"3", nil} (LH-06); a spaced hyphen too: "PART 2B - WALES" → {"2B", "WALES"}
  # (LR-05).
  defp number_parts(node, prefix) do
    raw =
      node
      |> xpath(~x"./Number/descendant::text()"ls)
      |> Enum.map_join("", &to_string/1)
      |> String.trim()
      # Strip the prefix word: "Part I" → "I", "SCHEDULE 1" → "1"
      |> String.replace(~r/^(?:#{prefix}|#{String.upcase(prefix)})\s+/i, "")
      |> String.replace(~r/^\s*<[^>]+>\s*/, "")
      |> String.trim()

    case String.split(raw, ~r/\.?\s*[—–]\s*|\s+-\s+/u, parts: 2) do
      [number, heading] ->
        {Xml.blank_to_nil(String.trim(number)), Xml.blank_to_nil(String.trim(heading))}

      [number] ->
        heading_as_number(node, prefix, Xml.blank_to_nil(number))
    end
  end

  # A Number holding a heading and no number ("Nuclear site licences" in
  # 1965/57): the number is the element id's ("part-2"), the text its
  # heading (LR-05). A number never contains a space.
  defp heading_as_number(node, prefix, text) do
    with true <- is_binary(text) and String.contains?(text, " "),
         [n] <-
           Regex.run(
             ~r/(?:^|-)#{String.downcase(prefix)}-([0-9A-Za-z]+)$/,
             Xml.xml_id(node) || "",
             capture: :all_but_first
           ) do
      {n, text}
    else
      _ -> {text, nil}
    end
  end

  @doc "A structural row with no title takes the heading its Number carries."
  @spec number_titled(map(), tuple(), String.t()) :: map()
  def number_titled(%{title: nil} = row, node, prefix) do
    case number_parts(node, prefix) do
      {_, nil} ->
        row

      {_, heading} ->
        %{row | title: heading, text: if(row.text in [nil, ""], do: heading, else: row.text)}
    end
  end

  def number_titled(row, _node, _prefix), do: row

  @doc "A heading's text (Title, else a Schedule's TitleBlock/Title), nil when blank."
  @spec title(tuple()) :: String.t() | nil
  def title(node) do
    # a Schedule's heading is in its TitleBlock (#165)
    case xpath(node, ~x"./Title"l) do
      [] -> node |> xpath(~x"./TitleBlock/Title"l) |> titles_text() |> Xml.blank_to_nil()
      titles -> titles |> titles_text() |> Xml.blank_to_nil()
    end
  end

  # A heading's text in document order (xmerl's //text() puts direct text
  # before descendants' text), inline markup joined without spaces
  # ("Re<Emphasis>gulators</Emphasis>", "CO<Sub>2</Sub>"), whitespace collapsed.
  # A retained territorial Repeal stays apart from the replacement that
  # follows it ("Powers of Entry Enforcement"; LAT parser coverage II item 3
  # renders those properly).
  # Some headings are split across Title elements ("International Oil
  # Pollution" + "Compensation Fund"): joined with a space.
  defp titles_text(titles), do: titles |> Enum.map_join(" ", &heading_text/1) |> String.trim()

  defp heading_text(element) do
    element |> inline_text() |> String.replace(~r/\s+/u, " ") |> String.trim()
  end

  defp inline_text(element) do
    {parts, _} =
      element
      |> elem(8)
      |> Enum.map_reduce(nil, fn child, prev ->
        case elem(child, 0) do
          :xmlText ->
            {child |> elem(4) |> to_string() |> LatSegments.strip_invisible(), nil}

          :xmlElement ->
            sep = if prev && territorial_pair?(prev, child), do: " ", else: ""
            {sep <> inline_text(child), child}

          _ ->
            {"", prev}
        end
      end)

    Enum.join(parts)
  end

  # <Repeal RetainText="true" SubstitutionRef="X">old</Repeal><Addition ChangeId="X">new</Addition>:
  # the old words kept for another territory, then their replacement.
  defp territorial_pair?(prev, next) do
    elem(prev, 1) == :Repeal and xpath(prev, ~x"./@RetainText"s) == "true" and
      xpath(prev, ~x"./@SubstitutionRef"s) not in ["", nil] and
      xpath(prev, ~x"./@SubstitutionRef"s) == xpath(next, ~x"./@ChangeId"s)
  end

  # The `title` column: a heading as written (Title, or a Schedule's
  # TitleBlock/Title), inline markup joined without spaces. Dots-only titles
  # (repealed headings) are nil. Row text keeps its own heading handling.
  @dots_title ~r/\A[\s.…]*\z/u

  @doc "The `title` column: the heading as written; dots-only (repealed) headings are nil."
  @spec heading_title(tuple()) :: String.t() | nil
  def heading_title(node) do
    title =
      case xpath(node, ~x"./Title"l) do
        [] -> node |> xpath(~x"./TitleBlock/Title"l) |> titles_text()
        titles -> titles_text(titles)
      end

    if Regex.match?(@dots_title, title), do: nil, else: title
  end

  @doc "The Pnumber of the first P1 inside (a Pblock's heading_group)."
  @spec first_p1_number(tuple()) :: String.t() | nil
  def first_p1_number(node) do
    case xpath(node, ~x".//P1[1]/Pnumber/descendant::text()"ls) do
      nil ->
        nil

      texts ->
        texts
        |> Enum.map(&to_string/1)
        |> Enum.join("")
        |> String.trim()
        |> case do
          "" -> nil
          v -> v
        end
    end
  end
end
