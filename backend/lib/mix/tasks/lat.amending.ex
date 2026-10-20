defmodule Mix.Tasks.Lat.Amending do
  @moduledoc """
  A law's amendment ruleset (amendment-rules AR-01, AR-03), one readable
  line per rule — the law and targets, the operation (words-level or whole
  provisions), its treatment, and the amending provision it came from:

      mix lat.amending --law UK_uksi_2014_1638

      UK_uksi_2014_1638 reg.69, reg.70 — substituted — instruction — UK_uksi_2019_696 sch.16.para.28: “For Part 13, Sub-Part C … substitute—”

  The read pass (AR-03) reads each amending law once — the provisions our
  laws' notes point to (one hop), for every law they point from — and stores
  its rules (`amendment_rules`) with a small index (element ids, each repeals
  table's introducing section) under `data/cache/amendment-index/`, so the
  collector needs no XML:

      mix lat.amending --read                    # every amending law not yet read (resumable)
      mix lat.amending --read --amending A,B     # these amending laws (re-read)
      mix lat.amending --read --limit 20         # the next 20

  One amending law at a time, each in its own process: a parsed amending
  law can take gigabytes (a 5-wide run exhausted memory, 2026-10-20).
  """

  use Mix.Task

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.AmendingLaw.{Doc, Locator, Pointer}
  alias SertantaiLegal.Scraper.Amendment.{Collect, Reader, Rule, Store}

  @index_dir "data/cache/amendment-index"

  @shortdoc "Print a law's amendment rules; read amending laws into rules"

  @impl Mix.Task
  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [law: :string, read: :boolean, amending: :string, limit: :integer]
      )

    Mix.Task.run("app.start")
    Logger.configure(level: :warning)

    cond do
      opts[:read] ->
        read(opts)

      opts[:law] ->
        for line <- opts[:law] |> Store.for_law() |> print(opts[:law]), do: Mix.shell().info(line)

      true ->
        Mix.raise("usage: mix lat.amending --law X | --read [--amending A,B] [--limit N]")
    end
  end

  @doc "The printed lines for a law's rules."
  @spec print([Rule.t()], String.t()) :: [String.t()]
  def print([], law), do: ["#{law}: no amendment rules (the readers write them: AR-03)"]

  def print(rules, law) do
    groups =
      rules
      |> Enum.group_by(& &1.source.law)
      |> Enum.sort()
      |> Enum.flat_map(fn {source, rs} ->
        ["", "  from #{source}" | Enum.map(rs, &("    " <> Rule.to_text(&1)))]
      end)

    ["#{law}: #{length(rules)} rule(s)" | groups]
  end

  @doc "The read pass's index for an amending law (`%{\"elements\" => …, \"references\" => …}`), or nil."
  @spec index(String.t()) :: map() | nil
  def index(amending) do
    case File.read(Path.join(@index_dir, "#{amending}.json")) do
      {:ok, json} -> Jason.decode!(json)
      _ -> nil
    end
  end

  # ── --read ──────────────────────────────────────────────────────────

  defp read(opts) do
    laws =
      case opts[:amending] do
        nil -> amending_laws() |> Enum.reject(&index_held?/1)
        list -> String.split(list, ",", trim: true)
      end

    laws = if opts[:limit], do: Enum.take(laws, opts[:limit]), else: laws
    Mix.shell().info("#{length(laws)} amending laws to read")

    for {a, i} <- Enum.with_index(laws, 1) do
      # in its own process: the parsed document goes when it exits
      {n, ids} = Task.async(fn -> read_one(a) end) |> Task.await(:infinity)
      mem = div(:erlang.memory(:total), 1_048_576)
      Mix.shell().info("  [#{i}/#{length(laws)}] #{a}: #{ids} provisions, #{n} rules (#{mem} MB)")
    end
  end

  # the laws our LAT laws' amendment notes point to, held in the CLML store
  defp amending_laws do
    Repo.query!("""
    SELECT DISTINCT coalesce(citation_law, changed_by) FROM amendment_annotations
    WHERE code_type = 'amendment' AND coalesce(citation_law, changed_by) ~ '^UK_'
      AND law_name IN (SELECT DISTINCT law_name FROM legal_articles)
    ORDER BY 1
    """).rows
    |> List.flatten()
    |> Enum.filter(&held?/1)
  end

  defp read_one(amending) do
    case doc(amending) do
      nil ->
        {0, 0}

      doc ->
        notes = notes_pointing_to(amending)
        laws = notes |> Enum.map(& &1.law_name) |> Enum.uniq() |> Enum.map(&law_ref/1)

        ids =
          for n <- notes,
              p = Pointer.parse(n),
              p.affecting_law == amending,
              ref <- p.provisions,
              id <- Locator.ids(doc, ref),
              uniq: true,
              do: id

        rules = Enum.flat_map(ids, &Collect.read(doc, &1, laws))
        {:ok, n} = Store.write(amending, rules)

        File.mkdir_p!(@index_dir)

        File.write!(
          Path.join(@index_dir, "#{amending}.json"),
          Jason.encode!(%{
            "elements" => Map.keys(doc.elements),
            "references" => Collect.references(doc)
          })
        )

        {n, length(ids)}
    end
  end

  defp notes_pointing_to(amending) do
    %{rows: rows} =
      Repo.query!(
        """
        SELECT law_name, code, text, citation_law, affected_sections FROM amendment_annotations
        WHERE code_type = 'amendment' AND coalesce(citation_law, changed_by) = $1
          AND law_name IN (SELECT DISTINCT law_name FROM legal_articles)
        """,
        [amending]
      )

    for [law, code, text, cl, sids] <- rows,
        do: %{
          law_name: law,
          code: code,
          text: text,
          citation_law: cl,
          affected_sections: sids || []
        }
  end

  # a LAT law's ref: its title (no year) and its rows' prefix
  defp law_ref(law) do
    title =
      case Repo.query!("SELECT title_en FROM uk_lrt WHERE name = $1 LIMIT 1", [law]) do
        %{rows: [[t]]} when is_binary(t) ->
          t |> String.replace(~r/\s+\d{4}\b.*$/, "") |> String.trim()

        _ ->
          nil
      end

    prefix =
      case Repo.query!(
             "SELECT substring(section_id from ':(s|reg|art|rule)\\.') FROM legal_articles WHERE law_name = $1 AND section_id ~ ':(s|reg|art|rule)\\.' LIMIT 1",
             [law]
           ) do
        %{rows: [[p]]} when is_binary(p) -> p
        _ -> "s"
      end

    Reader.law_ref(law, title, prefix)
  end

  defp index_held?(amending), do: File.exists?(Path.join(@index_dir, "#{amending}.json"))

  defp held?(law) do
    case String.split(law, "_", parts: 4) do
      [_, t, y, n] -> Path.wildcard("data/cache/clml/#{t}/#{y}/#{n}/**/data.xml.gz") != []
      _ -> false
    end
  end

  defp doc(law) do
    with [_, t, y, n] <- String.split(law, "_", parts: 4),
         [_ | _] = paths <- Path.wildcard("data/cache/clml/#{t}/#{y}/#{n}/**/data.xml.gz") do
      Doc.new(law, paths |> Enum.sort() |> Enum.map(&(&1 |> File.read!() |> :zlib.gunzip())))
    else
      _ -> nil
    end
  end
end
