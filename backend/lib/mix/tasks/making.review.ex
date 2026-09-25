defmodule Mix.Tasks.Making.Review do
  @moduledoc """
  Record a human Making verdict for one or more laws (QQ-01a).

  The verdict goes through `Legal.Making.record/4`: it becomes `making_review`
  (the top tier), `is_making` is re-resolved, and the change is logged in
  `record_change_log` with `changed_by: "making_review"` and the note.

      mix making.review UK_uksi_2008_198 --verdict not_making \\
        --note "amending SI: inserted duties sit in TA 1968"

      mix making.review UK_a UK_b --verdict making --note "…"
  """

  use Mix.Task

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Legal.Making

  require Ash.Query

  @shortdoc "Record a human Making verdict (making | not_making) with a note"

  @verdicts ~w(making not_making)

  @impl Mix.Task
  def run(args) do
    {opts, names, _} = OptionParser.parse(args, strict: [verdict: :string, note: :string])

    verdict = opts[:verdict]
    note = opts[:note]

    cond do
      names == [] ->
        Mix.raise("Give at least one law name")

      verdict not in @verdicts ->
        Mix.raise("--verdict must be one of: #{Enum.join(@verdicts, ", ")}")

      note in [nil, ""] ->
        Mix.raise("--note is required: say why")

      true ->
        :ok
    end

    Mix.Task.run("app.start")

    Enum.each(names, fn name ->
      with {:ok, [law]} <- LegalRegister |> Ash.Query.filter(name == ^name) |> Ash.read(),
           {:ok, updated} <-
             Making.record(law, %{making_review: verdict}, "making_review", note: note) do
        Mix.shell().info("#{name}: is_making=#{updated.is_making} (#{updated.is_making_reason})")
      else
        {:ok, []} -> Mix.shell().error("#{name}: not found")
        error -> Mix.shell().error("#{name}: #{inspect(error)}")
      end
    end)
  end
end
