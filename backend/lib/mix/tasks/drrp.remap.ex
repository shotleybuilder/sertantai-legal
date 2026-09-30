defmodule Mix.Tasks.Drrp.Remap do
  @moduledoc """
  Re-map stored provision DRRP types by the holder (the actor with
  `position: "active"`), after `ProvisionSubscriber.map_drrp_types/1` moved
  from "any governed actor present → Duty/Right" to the holder's role
  (2026-09-29; EPA 1990 s.20(7), legal #141 / fractalatai #67).

  Follows fractalaw docs/architecture/DRRP-CLASSIFICATION.md (fractalatai
  #68): a row with no active actor has an unknown holder and returns to raw
  Obligation/Liberty; each actor's `role` is re-stamped from its label
  (`ActorDefinitions.actor_role/1`) before mapping, and written back when it
  changed.

  Stored Duty/Responsibility are an Obligation, Right/Power a Liberty (rows
  stored as raw Obligation/Liberty are included); each row is re-mapped
  from its stored actors (per-actor `drrp` when present).

      mix drrp.remap            # dry run: transitions and counts
      mix drrp.remap --apply    # snapshot (id, drrp_types, actors) to drrp_remap_snapshot_<stamp>, then write
  """

  use Mix.Task

  alias SertantaiLegal.Legal.Taxa.ActorDefinitions
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Zenoh.ProvisionSubscriber

  @shortdoc "Re-map provision DRRP types by the holder (dry run by default)"

  @hohfeld %{
    "Duty" => "Obligation",
    "Responsibility" => "Obligation",
    "Right" => "Liberty",
    "Power" => "Liberty"
  }

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [apply: :boolean])
    Mix.Task.run("app.start")

    %{rows: rows} =
      Repo.query!(
        """
        SELECT section_id, law_name, drrp_types, actors FROM legal_articles
        WHERE drrp_types && ARRAY['Duty','Responsibility','Right','Power','Obligation','Liberty']
          AND actors IS NOT NULL
        """,
        [],
        timeout: :infinity
      )

    changes =
      for [sid, law, drrp, actors] <- rows,
          actors = Enum.map(actors, &decode/1),
          restamped = Enum.map(actors, &restamp/1),
          new = remap(drrp, restamped),
          new != drrp or restamped != actors,
          do: {sid, law, drrp, new, if(restamped != actors, do: restamped)}

    Mix.shell().info("Actor roles re-stamped: #{Enum.count(changes, &elem(&1, 4))} rows")

    Mix.shell().info(
      "Rows checked: #{length(rows)}; to change: #{length(changes)} in #{changes |> Enum.map(&elem(&1, 1)) |> Enum.uniq() |> length()} laws"
    )

    for {{from, to}, n} <-
          changes
          |> Enum.reject(fn {_, _, f, t, _} -> f == t end)
          |> Enum.frequencies_by(fn {_, _, f, t, _} -> {Enum.join(f, ","), Enum.join(t, ",")} end)
          |> Enum.sort_by(&(-elem(&1, 1))),
        do: Mix.shell().info("  #{from} → #{to}: #{n}")

    if opts[:apply], do: apply!(changes), else: Mix.shell().info("\nDry run: nothing written.")
  end

  defp remap(drrp, actors) do
    hohfeld = drrp |> Enum.map(&Map.get(@hohfeld, &1, &1)) |> Enum.uniq()

    %{drrp_types: new} =
      ProvisionSubscriber.map_drrp_types(%{drrp_types: hohfeld, actors: actors})

    Enum.uniq(new)
  end

  defp restamp(%{"label" => label} = actor) when is_binary(label),
    do: Map.put(actor, "role", ActorDefinitions.actor_role(label))

  defp restamp(actor), do: actor

  defp decode(a) when is_binary(a), do: Jason.decode!(a)
  defp decode(a), do: a

  defp apply!(changes) do
    table = "drrp_remap_snapshot_" <> Calendar.strftime(DateTime.utc_now(), "%Y%m%d_%H%M")

    Repo.transaction(
      fn ->
        Repo.query!(
          "CREATE TABLE #{table} AS SELECT section_id, law_name, drrp_types, actors FROM legal_articles WHERE section_id = ANY($1)",
          [Enum.map(changes, &elem(&1, 0))],
          timeout: :infinity
        )

        for {sid, _law, _from, to, actors} <- changes do
          Repo.query!("UPDATE legal_articles SET drrp_types = $2 WHERE section_id = $1", [sid, to])

          if actors,
            do:
              Repo.query!("UPDATE legal_articles SET actors = $2 WHERE section_id = $1", [
                sid,
                actors
              ])
        end
      end,
      timeout: :infinity
    )

    Mix.shell().info("\nApplied: #{length(changes)} rows (snapshot #{table})")
  end
end
