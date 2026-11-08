defmodule SertantaiLegal.Scraper.ChangeVocabulary.Golden do
  @moduledoc """
  The golden set: hand-verified provisions with their expected label periods
  (`test/fixtures/change_vocabulary/golden.exs`; with `extended: true` also
  `golden_extended.exs`, held for the pipeline's next pass). `mix
  lat.vocabulary --golden` prints the scoreboard.

  - `cases/1`, `laws/1`: the cases and their laws.
  - `law_labels/2`: one law's cases with the labels the vocabulary gives
    them, from its inputs (the law's text, feed and markup) or, with
    `stored: true`, from its stored changes.
  - `pass?/2`, `passed/1`: a case against its expected periods (tiers aside).
  - `line/1`, `tier_line/1`: a period as the scoreboard prints it.
  """

  alias SertantaiLegal.Scraper.{ChangeVocabulary, LatStagedParser}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Build, Fold, LabelSource, Store}

  @golden "test/fixtures/change_vocabulary/golden.exs"
  @golden_extended "test/fixtures/change_vocabulary/golden_extended.exs"

  @doc "The golden cases; with `extended: true`, the held-apart provisions too."
  @spec cases(keyword()) :: [map()]
  def cases(opts) do
    files = if opts[:extended], do: [@golden, @golden_extended], else: [@golden]
    Enum.flat_map(files, &elem(Code.eval_file(&1), 0))
  end

  @doc "The golden laws, once each."
  @spec laws(keyword()) :: [String.t()]
  def laws(opts), do: opts |> cases() |> Enum.map(& &1.law) |> Enum.uniq()

  @doc """
  One law's cases (`{law, entries}`) with the labels the vocabulary gives
  each: built from the law's inputs, or with `stored: true` folded from its
  stored changes.
  """
  @spec law_labels({String.t(), [map()]}, keyword()) :: [{map(), [map()] | nil}]
  def law_labels({law, entries}, opts) do
    xml = Build.clml(law)

    effects =
      law
      |> LatStagedParser.law_effects(store: :only)
      |> LatStagedParser.with_affecting_territory(law)

    containers = LabelSource.containers(law)

    provisions =
      Map.new(
        entries,
        &{&1.id,
         %{
           extent: &1.extent,
           start: &1.start,
           start_dated: not &1.undecidable,
           containers: Map.get(containers, &1.id, [])
         }}
      )

    given =
      if opts[:stored],
        do: [changes: Store.for_law(law), title: Build.title(law)],
        else:
          law
          |> Build.primary(effects)
          |> Keyword.merge(rows: law |> Build.rows() |> Map.keys(), xml_ids: Build.xml_ids(law))

    changes =
      Keyword.get_lazy(given, :changes, fn ->
        ChangeVocabulary.changes(law, xml, effects, provisions, given)
      end)

    labels = Fold.labels(law, xml, provisions, changes, given)
    Enum.map(entries, &{&1, labels[&1.id]})
  end

  @doc "A label's periods without their tiers."
  @spec untiered([map()] | nil) :: [map()]
  def untiered(periods), do: Enum.map(periods || [], &Map.delete(&1, :tiers))

  @doc "Whether a case's label gives its expected periods (tiers aside)."
  @spec pass?(map(), [map()] | nil) :: boolean()
  def pass?(c, periods), do: untiered(periods) == c.periods

  @doc "How many results pass."
  @spec passed([{map(), [map()] | nil}]) :: non_neg_integer()
  def passed(results), do: Enum.count(results, fn {c, got} -> pass?(c, got) end)

  @doc "A period as one line."
  @spec line(map()) :: String.t()
  def line(p),
    do:
      "#{p.valid_from} → #{p.valid_to || "…"}  #{p.status}  from #{p.in_force_from}  by #{inspect(p.changed_by)}" <>
        "#{if Map.get(p, :commenced_by, []) != [], do: "  commenced by #{inspect(p.commenced_by)}"}  #{p.territory}"

  @doc "A period's tier per field: the law's text (P) or legislation.gov.uk (D)."
  @spec tier_line(map() | nil) :: String.t()
  def tier_line(nil), do: ""

  def tier_line(tiers) do
    tiers
    |> Enum.sort()
    |> Enum.map_join(" ", fn {f, t} ->
      "#{f}:#{case t do
        :primary -> "P"
        :derived -> "D"
        nil -> "-"
      end}"
    end)
  end
end
