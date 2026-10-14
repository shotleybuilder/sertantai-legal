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
    |> Enum.map(&String.trim/1)
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

  defp continues?(last), do: last in [:section, :regulation, :article, :rule]

  defp subs(""), do: []
  defp subs(s), do: ~r/\(([^)]*)\)/ |> Regex.scan(s, capture: :all_but_first) |> List.flatten()

  defp blank(""), do: nil
  defp blank(s), do: s
end
