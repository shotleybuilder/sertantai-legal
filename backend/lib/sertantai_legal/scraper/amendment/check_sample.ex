defmodule SertantaiLegal.Scraper.Amendment.CheckSample do
  @moduledoc """
  The amendment reader's precision sample (change vocabulary CV-S06): the
  family's stored changes the amending law's own text states (a `:law_text`
  operation claim; the law's text alone, or with legislation.gov.uk), drawn
  at random by seed, each with what checking it needs — the change as
  merged (each attribute's winning source), the amending provision's own
  words, its rules, and legislation.gov.uk's claims on the same change.
  An agent judges the target, operation, level and amending law against the
  amending law's text (`amending-reader-check` skill). Reads the stored
  changes, `amendment_rules` and the CLML store; writes nothing.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Text}
  alias SertantaiLegal.Scraper.Amendment.ReadLaw
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Store}

  @source_key ~r/^(UK_[^:]+):(.+)$/

  @doc "The family's changes the law's text states: `{law, change}`."
  @spec population([String.t()]) :: [{String.t(), Change.t()}]
  def population(laws) do
    for law <- laws,
        c <- Store.for_law(law),
        Change.values(c, :law_text, :operation) != [],
        do: {law, c}
  end

  @doc "`n` of `population` at random by `seed`, in a stable order."
  @spec draw([{String.t(), Change.t()}], pos_integer(), integer()) :: [{String.t(), Change.t()}]
  def draw(population, n, seed) do
    :rand.seed(:exsss, {seed, 6, 6})

    population
    |> Enum.sort_by(fn {law, c} -> {law, c.target, c.key} end)
    |> Enum.shuffle()
    |> Enum.take(n)
  end

  @doc "One sampled change as a checkable item (JSON-ready map)."
  @spec item({String.t(), Change.t()}, pos_integer()) :: map()
  def item({law, %Change{} = c}, i) do
    sources = source_keys(c)
    r = c.resolved

    %{
      "n" => i,
      "law" => law,
      "target" => c.target,
      "key" => short(c.key),
      "stated_by" => stated_by(c),
      "change" => %{
        "operation" => str(r && r.operation),
        "level" => str(r && r.level),
        "by" => r && r.by,
        "won_by" => r && Map.new(r.sources, fn {k, v} -> {k, str(v)} end)
      },
      "law_text" => %{
        "operation" => c |> Change.values(:law_text, :operation) |> Enum.map(&str/1),
        "level" => c |> Change.values(:law_text, :level) |> Enum.map(&str/1)
      },
      "legislation_gov_uk" =>
        for(
          s <- [:feed, :markup],
          a <- [:operation, :level, :affecting],
          vs = Change.values(c, s, a),
          vs != [],
          into: %{},
          do: {"#{s}.#{a}", Enum.map(vs, &inspect_value/1)}
        ),
      "amending_provisions" => Enum.map(sources, &provision(&1, law))
    }
  end

  @doc "Who states the change: `both` (legislation.gov.uk too) or `law_text_only`."
  @spec stated_by(Change.t()) :: String.t()
  def stated_by(c), do: if(derived?(c), do: "both", else: "law_text_only")

  # the amending provisions behind the change: "law:element id" keys
  defp source_keys(%Change{} = c) do
    refs = for cl <- c.claims, cl.source == :law_text, do: cl.ref

    (refs ++ c.aliases ++ [c.key])
    |> Enum.filter(&(is_binary(&1) and &1 =~ @source_key))
    |> Enum.uniq()
  end

  defp provision(key, law) do
    [_, amending, id] = Regex.run(@source_key, key)
    doc = doc(amending)
    text = doc && Text.of(doc, id)

    %{
      "amending_law" => amending,
      "provision" => id,
      "headings" => if(doc, do: Enum.take(Doc.headings(doc, id), 2), else: []),
      "context" =>
        if(text, do: text.context |> Enum.take(2) |> Enum.map(&cut(&1, 300)), else: []),
      "parents" => if(text, do: Enum.map(text.parents, &cut(&1, 300)), else: []),
      "instruction" => text && cut(text.instruction, 700),
      "quoted" => text && cut(text.quoted, 400),
      "quoted_provisions" => if(text, do: Enum.map(text.inserted, &Enum.join(&1, "/")), else: []),
      "rules" => rules(amending, id, law)
    }
  end

  defp rules(amending, id, law) do
    Repo.query!(
      """
      SELECT operation, level, treatment, targets FROM amendment_rules
      WHERE source_law = $1 AND source_ref = $2 AND amends = $3
      """,
      [amending, id, law]
    ).rows
    |> Enum.map(fn [op, level, treatment, targets] ->
      %{"operation" => op, "level" => level, "treatment" => treatment, "targets" => targets}
    end)
  end

  # each amending law parsed once per run
  defp doc(amending) do
    case Process.get({__MODULE__, amending}, :none) do
      :none -> tap(ReadLaw.doc(amending), &Process.put({__MODULE__, amending}, &1))
      d -> d
    end
  end

  defp derived?(c),
    do: Change.values(c, :feed, :operation) != [] or Change.values(c, :markup, :operation) != []

  # an effect id's last six characters (never committed whole)
  defp short("key-" <> rest), do: "key-…" <> String.slice(rest, -6, 6)
  defp short(key), do: key

  defp str(nil), do: nil
  defp str(v) when is_atom(v), do: Atom.to_string(v)
  defp str(v) when is_binary(v), do: v
  defp str(v), do: inspect(v)

  defp inspect_value(v) when is_binary(v) or is_atom(v), do: str(v)
  defp inspect_value(v) when is_list(v), do: Enum.map(v, &inspect_value/1)
  defp inspect_value(v), do: inspect(v)

  defp cut(nil, _), do: nil
  defp cut(s, n), do: String.slice(s, 0, n)
end
