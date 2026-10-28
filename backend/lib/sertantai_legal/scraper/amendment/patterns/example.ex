defmodule SertantaiLegal.Scraper.Amendment.Patterns.Example do
  @moduledoc """
  An amending provision's catalogue example (CV-S06): the amending law's
  documents pruned to what reading the provision needs — its top provision
  whole, the containers above it as shells with their titles (the
  headings the reader looks in), and as few earlier top provisions as
  make its reading the same as in the whole law (`build/5`: the text
  before is read for the law's name). An example that never reads the same
  is not held (counted). Pure.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc
  alias SertantaiLegal.Scraper.Amendment.{Patterns, Reader, Rule}
  alias SertantaiLegal.Scraper.LatParser.Xml

  @kinds Map.new(~w(section regulation article rule)a, &{Atom.to_string(&1), &1})

  # the earlier top provisions tried, nearest first
  @max_earlier 40
  # a container's own words kept in a shell
  @shell_children ~w(Title TitleBlock Number Pnumber)a

  @doc """
  The example for provision `id` of `doc`, read for `law` with `terms`:
  `{:ok, xmls}` (one per document kept) when its class alone is `class`
  (`Patterns.class/4`: the pattern and the rules), else `:error`.
  """
  @spec build(Doc.t(), String.t(), map(), Reader.law_ref(), {String.t(), [Rule.t()]}) ::
          {:ok, [String.t()]} | :error
  def build(doc, id, terms, law, class) do
    own = top(id)
    earlier = earlier(doc, own)

    [[own] | Enum.map(1..@max_earlier, &[own | Enum.take(earlier, &1)])]
    |> Stream.uniq()
    |> Stream.map(&xmls(doc, MapSet.new(&1)))
    |> Enum.find_value(:error, fn xmls ->
      if read(doc.law_name, xmls, id, terms, law) == class, do: {:ok, xmls}
    end)
  end

  @doc "The class an example (`build/5`'s XML) gives provision `id` (`Patterns.class/4`)."
  @spec read(String.t(), [String.t()], String.t(), map(), Reader.law_ref()) ::
          {String.t(), [Rule.t()]}
  def read(law_name, xmls, id, terms, law),
    do: law_name |> Doc.new(xmls) |> Patterns.class(id, terms, law)

  @doc "An example as JSON: its documents, the amending law's defined terms and the law read for."
  @spec to_json([String.t()], map(), Reader.law_ref()) :: map()
  def to_json(xmls, terms, law),
    do: %{"xmls" => xmls, "terms" => terms, "law" => Map.update!(law, :kind, &Atom.to_string/1)}

  @doc "An example from its JSON (`to_json/3`): `{xmls, terms, law}`."
  @spec from_json(map()) :: {[String.t()], map(), Reader.law_ref()}
  def from_json(%{"xmls" => xmls, "terms" => terms, "law" => law}) do
    {xmls, Map.new(terms, fn {k, v} -> {k, %{law: v["law"], title: v["title"]}} end),
     %{
       law_name: law["law_name"],
       title: law["title"],
       year: law["year"],
       number: law["number"],
       kind: Map.fetch!(@kinds, law["kind"])
     }}
  end

  # the top provision holding `id`; an id with none (a table) itself
  defp top(id) do
    case Regex.run(
           ~r/^(schedule-[^-]+-paragraph-[^-]+|(?:section|regulation|article|rule)-[^-]+)/,
           id
         ) do
      [_, top] -> top
      nil -> id
    end
  end

  defp top?(id),
    do: id =~ ~r/^(?:schedule-[^-]+-paragraph-[^-]+|(?:section|regulation|article|rule)-[^-]+)$/

  # the top provisions before `own` in its Schedule (then the body's
  # naming that Schedule), or in the body, nearest first — where the reader
  # looks for the law's name (`Text.before`)
  defp earlier(doc, own) do
    at = Map.get(doc.pos, own, 0)
    before = doc.ids |> Enum.take(at) |> Enum.reverse() |> Enum.filter(&top?/1)
    {body, schedules} = Enum.split_with(before, &(not String.starts_with?(&1, "schedule-")))

    case Regex.run(~r/^(schedule-([^-]+)-)/, own) do
      [_, prefix, n] ->
        naming = ~r/\bSchedules? (?:[\dA-Z]+(?:,| and| to) )*#{Regex.escape(n)}\b/

        Enum.filter(schedules, &String.starts_with?(&1, prefix)) ++
          for(
            i <- doc.ids,
            top?(i),
            not String.starts_with?(i, "schedule-"),
            Regex.match?(naming, doc |> Doc.element(i) |> Doc.text()),
            do: i
          )

      nil ->
        body
    end
  end

  defp xmls(doc, keep) do
    for root <- doc.roots,
        pruned = prune(root, keep),
        pruned != nil,
        do: export(pruned)
  end

  # an element kept whole, an ancestor of one kept as a shell (its title
  # and number, and what it holds that is kept), or dropped
  defp prune({:xmlElement, _, _, _, _, _, _, _, content, _, _, _} = el, keep) do
    if MapSet.member?(keep, Xml.attr_or_nil(el, :id)) do
      el
    else
      kept =
        for c <- content,
            p = child(c, keep),
            p != nil,
            do: p

      if Enum.any?(kept, &(elem(&1, 0) == :xmlElement and elem(&1, 1) not in @shell_children)),
        do: put_elem(el, 8, kept),
        else: nil
    end
  end

  defp prune(_node, _keep), do: nil

  defp child({:xmlElement, name, _, _, _, _, _, _, _, _, _, _} = el, _keep)
       when name in @shell_children,
       do: el

  defp child({:xmlElement, _, _, _, _, _, _, _, _, _, _, _} = el, keep), do: prune(el, keep)
  defp child(_node, _keep), do: nil

  # legislation.gov.uk effect ids shortened to their last six characters:
  # never committed whole (they trip secret scanning); the reading doesn't
  # use them, and `build/5` checks the example still reads the same
  defp export(el) do
    [el]
    |> :xmerl.export(:xmerl_xml, prolog: [])
    |> :unicode.characters_to_binary()
    |> then(&Regex.replace(~r/key-[0-9a-f]{26}([0-9a-f]{6})/, &1, "key-\\1"))
  end
end
