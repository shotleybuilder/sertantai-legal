defmodule SertantaiLegal.Scraper.ChangeVocabulary.StaleStages do
  @moduledoc """
  What is stale, stage by stage (#194), for `mix lat.vocabulary --build
  --stale` and `mix lat.stale`: the changes stage's built laws whose code
  or inputs moved (`ChangeStaleness`), then the labels stage's switched
  laws whose fold, folded changes or fold inputs moved (`LabelStaleness`),
  and what each stale label needs (`label_action/1`, pure). The labels are
  read after the changes are rebuilt: a rebuild giving the same output
  digest stales no label.

  Reads the database (`Store`, `LabelStaleness.facts/0`); writes nothing.
  """

  alias SertantaiLegal.Scraper.{ChangeStaleness, LabelStaleness}
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Store, Version}

  # labels the fold alone brings up to date, from the stored changes
  @refold [:fold_version, :labels_behind_changes, :fold_inputs]
  # labels a refresh brings up to date: the law's changes built, then folded
  @refresh [:labels_behind_parse, :labels_failed]

  @doc """
  Each built law → `{reasons, inputs now}`: its change staleness against
  the code and its inputs taken now (empty reasons: fresh).
  """
  @spec changes() :: %{String.t() => {[ChangeStaleness.reason()], map()}}
  def changes do
    version = Version.current()

    Map.new(Store.builds(), fn {law, b} ->
      {affecting, sources} = {b.affecting || [], b.commencement_sources || []}
      inputs = Store.Inputs.of(law, affecting, sources)
      readers = Store.Inputs.readers(law, affecting, sources)
      current = %{code_version: version, inputs: inputs, readers: readers}
      {law, {ChangeStaleness.reasons(b, current), inputs}}
    end)
  end

  @doc "The built laws whose changes are stale, sorted."
  @spec stale_changes() :: [String.t()]
  def stale_changes,
    do: for({law, {[_ | _], _}} <- Enum.sort(changes()), do: law)

  @doc "Each switched law whose labels are stale, with its reasons, sorted."
  @spec stale_labels() :: [{String.t(), [LabelStaleness.reason()]}]
  def stale_labels do
    current = LabelStaleness.current()

    for {law, %{switched: true} = f} <- LabelStaleness.facts(),
        reasons = LabelStaleness.reasons(f, current),
        reasons != [],
        do: {law, reasons}
  end

  @doc """
  What a switched law's stale labels need: `:refresh` (built, then folded:
  a parse or a failed refresh since), `:refold` (folded from its stored
  changes: the fold's code, the changes or its inputs moved), or `:reparse`
  (nothing here mends them: the parse itself is stale, `mix lat.reparse`).
  """
  @spec label_action([LabelStaleness.reason()]) :: :refresh | :refold | :reparse
  def label_action(reasons) do
    cond do
      Enum.any?(reasons, &(&1 in @refresh)) -> :refresh
      Enum.all?(reasons, &(&1 in @refold)) -> :refold
      true -> :reparse
    end
  end
end
