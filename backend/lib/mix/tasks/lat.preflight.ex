defmodule Mix.Tasks.Lat.Preflight do
  @moduledoc """
  The pre-flight before any write or rebuild in a family's step
  (Environmental Protection retrospective; Amending-law reader: review
  tooling): seconds to minutes of checks, never a full chain as a debug
  loop. In order:

  - the compile with warnings as errors (`MIX_ENV=dev`), and the
    architecture tests (`test/sertantai_legal/architecture`), each in its
    own process; a failed compile stops the rest, which would run old code;
  - golden from inputs (`mix lat.vocabulary --golden`, about 4½ min);
  - the switch-over's checked rows (`mix lat.label_checked`);
  - with `--laws L1,L2`, the label fold's gate on those laws alone
    (`mix lat.label_check --family F --gate --laws`).

  One line per check (`ChangeVocabulary.Gate.Step`); exits non-zero when
  any fails. Read-only. The step's close is `mix lat.step_close`.

      mix lat.preflight --family "ENVIRONMENTAL PROTECTION"
      mix lat.preflight --family F --laws UK_ukpga_1990_43,UK_uksi_2016_1154
  """
  use Mix.Task

  alias Mix.Tasks.Lat.Gates
  alias SertantaiLegal.Scraper.ChangeVocabulary.Gate.Step

  @shortdoc "The pre-flight before a step's writes: compile, architecture, golden, checked rows (read-only)"

  @usage "usage: mix lat.preflight --family F [--laws L1,L2]"

  @code [
    {"Compile", "dev", ["compile", "--warnings-as-errors"]},
    {"Architecture tests", "test", ["test", "test/sertantai_legal/architecture"]}
  ]

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [family: :string, laws: :string])
    family = opts[:family] || Mix.raise(@usage)

    code = Enum.map(@code, &command/1)
    results = if Step.summary(code).pass?, do: code ++ data(family, opts[:laws]), else: code

    summary = Step.summary(results)
    Mix.shell().info("\npre-flight, #{family}:")
    for l <- summary.lines, do: Mix.shell().info("  #{l}")
    Mix.shell().info("\n#{if summary.pass?, do: "PASS", else: "FAIL"} (pre-flight)")

    if not summary.pass?, do: exit({:shutdown, 1})
    summary
  end

  defp data(family, laws) do
    [
      Gates.check("Golden", "lat.vocabulary", ["--golden"]),
      Gates.check("Checked rows", "lat.label_checked", [])
    ] ++
      if laws,
        do: [
          Gates.check("Label fold", "lat.label_check", [
            "--family",
            family,
            "--gate",
            "--laws",
            laws
          ])
        ],
        else: []
  end

  # a code check in its own process, so it sees the code on disk
  defp command({name, env, args}) do
    Mix.shell().info("\n── #{name} (MIX_ENV=#{env} mix #{Enum.join(args, " ")}) ──")
    {out, status} = System.cmd("mix", args, env: [{"MIX_ENV", env}], stderr_to_stdout: true)
    Mix.shell().info(out |> String.split("\n") |> Enum.take(-6) |> Enum.join("\n"))

    Step.new(name, status == 0, if(status == 0, do: 0, else: 1),
      owner: "the code being committed"
    )
  end
end
