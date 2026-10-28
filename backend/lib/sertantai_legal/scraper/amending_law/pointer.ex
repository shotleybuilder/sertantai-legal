defmodule SertantaiLegal.Scraper.AmendingLaw.Pointer do
  @moduledoc """
  Where a note says a change was made — the amending law and its
  provisions, and the commencing instrument — and nothing else (lat-refactor
  LR-08). A note is a pointer, never a fact: no date, operation or target is
  read here; those come from the law's own text.

  "… by 2000 c. 27, s. 108, Sch. 6 Pt. II para. 33(c); S.I. 2001/3266, art. 2"
  → amending law UK_ukpga_2000_27, provisions [s. 108, Sch. 6 Pt. II para.
  33(c)], commencing [UK_uksi_2001_3266: art. 2].

  Refs: `{:section | :regulation | :article | :rule, number, subs}` and
  `{:schedule, number | nil, part | nil, paragraph | nil, subs}`; `subs` are
  the bracketed parts as written ("(5)(7)" → ["5", "7"]). Pure.
  """

  @enforce_keys [:note_code]
  defstruct [:note_code, :affecting_law, provisions: [], commencing: []]

  @type ref ::
          {:section | :regulation | :article | :rule, String.t(), [String.t()]}
          | {:schedule, String.t() | nil, String.t() | nil, String.t() | nil, [String.t()]}

  @type t :: %__MODULE__{
          note_code: String.t(),
          affecting_law: String.t() | nil,
          provisions: [ref()],
          commencing: [{String.t(), [ref()]}]
        }

  @bare ~r/^(\d+[A-Z]*)((?:\([^)]*\))*)$/
  @si_types %{"S.I." => "uksi", "S.S.I." => "ssi", "S.R." => "nisr", "W.S.I." => "wsi"}
  @si ~r/\b(S\.S\.I\.|W\.S\.I\.|S\.I\.|S\.R\.)\s*(\d{4})\/(\d+)/
  @kinds %{
    "s" => :section,
    "ss" => :section,
    "reg" => :regulation,
    "regs" => :regulation,
    "art" => :article,
    "arts" => :article,
    "rule" => :rule,
    "rules" => :rule
  }

  @doc "The pointer in a note (`code`, `text`, `citation_law`)."
  @spec parse(map()) :: t()
  def parse(note) do
    law = Map.get(note, :citation_law)
    text = Map.get(note, :text) || ""
    pointer = %__MODULE__{note_code: Map.get(note, :code), affecting_law: law}

    with law when is_binary(law) <- law,
         {pos, len} <- citation(text, law) do
      [own | rest] =
        text |> binary_part(pos + len, byte_size(text) - pos - len) |> String.split(";")

      %{pointer | provisions: refs(own), commencing: Enum.flat_map(rest, &commencing/1)}
    else
      _ -> pointer
    end
  end

  # where the text cites the law: "2000 c. 27", "(c. 27, SIF 102)" after its
  # year, "S.I. 2010/675"
  defp citation(text, law) do
    case String.split(law, "_") do
      [_, type, year, number] -> match(text, type, year, number)
      _ -> nil
    end
  end

  defp match(text, type, year, number) when type in ~w(uksi ssi nisr wsi) do
    si = Enum.find_value(@si_types, fn {k, v} -> if v == type, do: k end)
    re = Regex.compile!("#{Regex.escape(si)}\\s*#{year}\\/#{number}\\b")
    first(re, text)
  end

  defp match(text, _type, year, number) do
    first(~r/\b#{year}\s*\(?c\.\s*#{number}\b[^,;)]*\)?/, text) ||
      first(~r/#{year}\s*\(c\.\s*#{number}\b[^)]*\)/, text)
  end

  defp first(re, text) do
    case Regex.run(re, text, return: :index) do
      [{pos, len} | _] -> {pos, len}
      nil -> nil
    end
  end

  @doc """
  The amending provisions a changes-feed effect names ("Sch. 7 para. 27(2)
  Sch. 17 Pt. 2", "s. 111, Sch. 7") as refs, read as a note's are — the
  feed and the notes are both pointers to where the amending law's text is
  read (CV-07; Jason 2026-10-22: "both pointers … we mustn't duplicate").
  """
  @spec refs_in(String.t() | nil) :: [ref()]
  def refs_in(nil), do: []

  def refs_in(text),
    do: text |> String.replace(~r/\s+(?=Schs?\.)/, ", ") |> refs()

  # a commencing instrument after ";": "S.I. 2001/3266, art. 2, Sch."
  defp commencing(segment) do
    case Regex.run(@si, segment, return: :index) do
      [{pos, len} | _] ->
        [_, kind, year, number] = Regex.run(@si, segment)
        tail = binary_part(segment, pos + len, byte_size(segment) - pos - len)
        [{"UK_#{@si_types[kind]}_#{year}_#{number}", refs(tail)}]

      nil ->
        []
    end
  end

  # the provision refs in a pointer tail, a bare number continuing the last
  # kind ("ss. 140(8), 152(3)")
  defp refs(tail) do
    tail
    |> String.split(",")
    # (a pointer in braces: "{Sch. Pt. 1 para. 8(a)(i)}", CV-S07 round 3)
    |> Enum.map(
      &(&1
        |> String.trim()
        |> String.trim_leading("{")
        |> String.trim_trailing("}")
        |> String.trim())
    )
    |> Enum.reduce({[], nil}, fn token, {acc, last} ->
      case ref(token, last) do
        nil -> {acc, last}
        r -> {[r | acc], elem(r, 0)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp ref(token, last) do
    cond do
      m =
          Regex.run(
            ~r/^Schs?\.?\s*(\d+[A-Z]*)?\s*(?:Pt\.?\s*([IVXLC]+|\d+[A-Z]*))?\s*(?:paras?\.\s*(\d+[A-Z]*)((?:\([^)]*\))*))?/i,
            token
          ) ->
        [_ | groups] = m
        [number, part, para, subs] = groups ++ List.duplicate("", 4 - length(groups))
        {:schedule, blank(number), blank(part), blank(para), subs(subs)}

      m =
          Regex.run(
            ~r/^(ss|s|regs|reg|arts|art|rules|rule)\.?\s*(\d+[A-Z]*)((?:\([^)]*\))*)/i,
            token
          ) ->
        [_, kind, number, subs] = m
        {@kinds[String.downcase(kind)], number, subs(subs)}

      continues?(last) && Regex.match?(@bare, token) ->
        [_, number, subs] = Regex.run(@bare, token)
        {last, number, subs(subs)}

      true ->
        nil
    end
  end

  @doc """
  A pointer's provision as a ref in the feed's grammar, for identity only
  (change vocabulary CV-04: telling apart same-day events by one law):
  `{:schedule, "2", nil, "10", ["2", "a"]}` → `"sch.2.para.10(2)(a)"`. Nil
  when it names no number.
  """
  @spec to_ref(tuple()) :: String.t() | nil
  # an unnumbered Schedule's paragraph, as the markup's structured pointers
  # name it ("Sch. para. 8(a)(ii)" → "sch.para.8(a)(ii)": CV-S07 round 3)
  def to_ref({:schedule, nil, _part, para, subs}) when is_binary(para),
    do: "sch.para.#{para}#{brackets(subs)}"

  def to_ref({:schedule, nil, _part, _para, _subs}), do: nil

  def to_ref({:schedule, n, _part, para, subs}) when is_binary(para),
    do: "sch.#{n}.para.#{para}#{brackets(subs)}"

  def to_ref({:schedule, n, part, nil, _subs}) when is_binary(part), do: "sch.#{n}.pt.#{part}"
  def to_ref({:schedule, n, nil, nil, _subs}), do: "sch.#{n}"

  def to_ref({kind, n, subs}) do
    prefix = %{section: "s", regulation: "reg", article: "art", rule: "rule"}[kind]
    if prefix, do: "#{prefix}.#{n}#{brackets(subs)}"
  end

  defp brackets(subs), do: Enum.map_join(subs, &"(#{&1})")

  @doc """
  The refs a pointer's provision names: a run of brackets of one kind is a
  list of items, not a path ("para. 9(b)(c)(d)" → 9(b), 9(c), 9(d);
  "para. 4(4)(a)" stays one path).
  """
  @spec to_refs(tuple()) :: [String.t()]
  def to_refs(ref) do
    {subs, rebuild} =
      case ref do
        {:schedule, n, part, para, subs} -> {subs, &{:schedule, n, part, para, &1}}
        {kind, n, subs} -> {subs, &{kind, n, &1}}
      end

    case Enum.find_index(Enum.chunk_every(subs, 2, 1, :discard), fn [a, b] -> listed?(a, b) end) do
      nil ->
        List.wrap(to_ref(ref))

      i ->
        {path, items} = Enum.split(subs, i)
        for item <- items, r = to_ref(rebuild.(path ++ [item])), r != nil, do: r
    end
  end

  # two brackets of one kind in a row are list items, letters only where
  # the second follows the first ("9(b)(c)": items; "8(a)(i)": a path —
  # (i) the roman below (a), CV-S07 round 3)
  defp listed?(a, b) do
    case {kind(a), kind(b)} do
      {:letter, :letter} -> String.to_charlist(b) == Enum.map(String.to_charlist(a), &(&1 + 1))
      {k, k} -> true
      _ -> false
    end
  end

  defp kind(s) do
    cond do
      s =~ ~r/^\d/ -> :number
      s =~ ~r/^[a-z]$/ -> :letter
      s =~ ~r/^[ivxl]+$/ -> :roman
      s =~ ~r/^[A-Z]+$/ -> :capital
      true -> :other
    end
  end

  defp continues?(last), do: last in [:section, :regulation, :article, :rule]

  # the leading run of bracketed numbers ("(4)(with s. 84(5))" → ["4"]:
  # words in brackets end it)
  defp subs(""), do: []

  defp subs(s) do
    [run] = Regex.run(~r/^(?:\([A-Za-z0-9]+\))*/, s)
    ~r/\(([A-Za-z0-9]+)\)/ |> Regex.scan(run, capture: :all_but_first) |> List.flatten()
  end

  defp blank(""), do: nil
  defp blank(s), do: s
end
