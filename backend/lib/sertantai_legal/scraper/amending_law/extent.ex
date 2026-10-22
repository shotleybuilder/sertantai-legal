defmodule SertantaiLegal.Scraper.AmendingLaw.Extent do
  @moduledoc """
  An amending Act's own extent clause, read (change vocabulary CV-03;
  primary text): where each of its provisions extends, so where a change it
  makes applies. Serious Organised Crime and Police Act 2005 s.179:

  - "(2) … this Act extends to England and Wales only" — the default;
  - "(3) The following extend also to Scotland— sections 1 to 54 …" —
    the default and that territory;
  - "(4) The following extend to Scotland only— …" — that territory;
  - "(7) The following have the same extent as the enactments to which
    they relate— … section 174(2) and Schedule 17" — the amended law's
    (a repeals schedule follows the enactment it repeals);
  - "(8) So far as Schedule 17 contains a repeal … which corresponds to the
    repeal … by another provision of this Act, that Schedule … [has] the
    same extent as that other provision" — `corresponds: true`.

  A Schedule extends as the section introducing it ("111 Schedule 7 … has
  effect"), unless the clause names it. `read/1` takes the Act's document;
  `of/3` answers for one provision: a territory code, `:same` (the
  enactment's own), or nil (not read). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, RefList}
  alias SertantaiLegal.Scraper.Commencement.Order
  alias SertantaiLegal.Scraper.Territory

  defstruct default: nil, lists: [], corresponds: false, introduced_by: %{}

  @type list_kind :: :also | :only | :same
  @type t :: %__MODULE__{
          default: String.t() | nil,
          lists: [{list_kind(), String.t() | nil, [String.t()]}],
          corresponds: boolean(),
          introduced_by: %{String.t() => String.t()}
        }

  @places "England and Wales|Great Britain|England|Wales|Scotland|Northern Ireland"
  @codes %{
    "england and wales" => "E+W",
    "great britain" => "E+W+S",
    "england" => "E",
    "wales" => "W",
    "scotland" => "S",
    "northern ireland" => "NI"
  }

  @doc "The Act's extent clause read from its document; empty when it has none read."
  @spec read(Doc.t()) :: t()
  def read(%Doc{} = doc) do
    # lines joined with spaces: a paragraph label never runs into the
    # words before it ("Schedule 10.7 The following …")
    sections =
      for id <- doc.ids,
          ref = Order.ref(id),
          ref != nil,
          do: {ref, doc |> Doc.element(id) |> Doc.lines() |> Enum.join(" ")}

    {clause_ref, clause} =
      Enum.find(sections, {nil, ""}, fn {ref, text} ->
        not String.contains?(ref, "(") and
          Regex.match?(~r/\bthis Act extends to (?:#{@places})(?: only)?\b/i, text)
      end)

    %__MODULE__{
      default: default(clause),
      lists: lists(clause, clause_ref),
      corresponds: Regex.match?(~r/\bcorresponds\s+to\s+the\s+repeal\b/i, clause),
      introduced_by: introductions(sections)
    }
  end

  defp default(clause) do
    case Regex.run(~r/\bthis Act extends to (#{@places})(?: only)?\b/i, clause) do
      [_, place] -> @codes[String.downcase(place)]
      nil -> nil
    end
  end

  # each list: "The following extend also to Scotland— …", "… to Scotland
  # only— …", "… have the same extent as the enactments to which they
  # relate— …", up to the next such heading
  @heading ~r/The following (?:extend(?:s)? (also )?to (#{@places})( only)?|ha(?:s|ve) the same extent as the enactments? to which (?:it|they) relates?)\s*[—–:-]/iu

  defp lists(clause, clause_ref) do
    parts = Regex.split(@heading, clause, include_captures: true, trim: true)

    parts
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn [head, body] ->
      case Regex.run(@heading, head) do
        nil -> []
        match -> [{kind(match), place(match), refs(cut(body), clause_ref)}]
      end
    end)
  end

  defp kind([whole | _]) do
    cond do
      whole =~ ~r/same extent/i -> :same
      whole =~ ~r/\bonly\b/i -> :only
      true -> :also
    end
  end

  defp place([whole | _]) do
    case Regex.run(~r/\bto (#{@places})\b/i, whole) do
      [_, p] -> @codes[String.downcase(p)]
      nil -> nil
    end
  end

  # the list ends at the next subsection's words ("(8) So far as …")
  # (and before the next list's heading, its subsection number: "… and 15.4")
  defp cut(body),
    do:
      body
      |> String.split(~r/\.\s*\d+[A-Z]?\s+(?=[A-Z])/u, parts: 2)
      |> hd()
      |> String.replace(~r/\.\s*\d+[A-Z]?\s*$/u, ".")

  defp refs(text, clause_ref), do: RefList.parse(text, clause_ref)

  # each Schedule's introducing section: "111 Schedule 7, which supplements
  # section 110 …, has effect"
  defp introductions(sections) do
    for {ref, text} <- sections,
        not String.contains?(ref, "("),
        [_, n] <-
          Regex.scan(
            ~r/\bSchedule\s+(\d+[A-Z]*)\b[^.]{0,300}?\b(?:has|shall have) effect\b/u,
            text
          ),
        into: %{},
        do: {"sch.#{n}", ref}
  end

  @doc """
  Where the amending provision `ref` ("s.111", "sch.7.para.27(2)",
  "sch.17.pt.2") extends: a territory code, `:same` (the enactment it
  changes), or nil (the clause wasn't read).
  """
  @spec of(t(), String.t()) :: String.t() | :same | nil
  def of(%__MODULE__{default: nil}, _ref), do: nil

  def of(%__MODULE__{} = e, ref) do
    candidates = [ref | containers(ref)] ++ introducing(e, ref)

    Enum.find_value(e.lists, fn {kind, place, items} ->
      if Enum.any?(candidates, &named?(&1, items)) do
        case kind do
          :only -> place
          :also -> Territory.union([e.default, place])
          :same -> :same
        end
      end
    end) || e.default
  end

  # "sch.7.para.27(2)" → ["sch.7.para.27", "sch.7"]; "sch.17.pt.2" → ["sch.17"]
  defp containers(ref) do
    case Regex.run(~r/^(sch\.\d+[A-Z]*)/, ref) do
      [_, sch] -> Enum.reject([String.replace(ref, ~r/\(.*$/, ""), sch], &(&1 == ref))
      nil -> [String.replace(ref, ~r/\(.*$/, "")] |> Enum.reject(&(&1 == ref))
    end
  end

  # a Schedule not named in the clause extends as its introducing section
  defp introducing(e, ref) do
    case Regex.run(~r/^(sch\.\d+[A-Z]*)/, ref) do
      [_, sch] -> List.wrap(Map.get(e.introduced_by, sch))
      nil -> []
    end
  end

  defp named?(ref, items), do: Enum.any?(items, &RefList.covers?(&1, ref))

  @doc """
  The territory of a change made by the amending provisions `refs` (an
  effect may name several: "Sch. 7 para. 27(2) Sch. 17 Pt. 2"): a repeals
  schedule with the enactment's extent follows the provision it corresponds
  to (`corresponds`); the provisions that remain must agree. Nil when none
  is read, or they disagree.
  """
  @spec of_change(t(), [String.t()]) :: String.t() | :same | nil
  def of_change(%__MODULE__{} = e, refs) do
    extents = Enum.map(refs, &of(e, &1))

    extents =
      if e.corresponds and Enum.any?(extents, &is_binary/1),
        do: Enum.reject(extents, &(&1 == :same)),
        else: extents

    case Enum.uniq(extents) do
      [one] -> one
      _ -> nil
    end
  end
end
