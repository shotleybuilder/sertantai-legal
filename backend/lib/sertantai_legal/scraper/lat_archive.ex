defmodule SertantaiLegal.Scraper.LatArchive do
  @moduledoc """
  Discarding a law's LAT deliberately (enrichment readiness, 2026-09-27).

  LAT is kept only for Making laws. When a law's LAT is dropped (not Making,
  revoked, …) its rows are first archived to the NAS so the evidence — text
  and any enrichment — survives, and a later decision can restore it rather
  than re-parse:

      <dir>/<law_name>/<lat_hash>.jsonl.gz     one `row_to_json` line per row

  `discard/3` archives, sets the `lat_events` context (reason, source, actor,
  archive_ref) and deletes, so the trigger records a `discarded` event
  pointing at the archive. It refuses if the archive cannot be written,
  unless `archive: false`.

  Directory: `:dir` option, else `config :sertantai_legal, :lat_archive_dir`,
  else `/mnt/nas/sertantai-data/data/lat-archive`.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.LatScope
  alias SertantaiLegal.Scraper.LatPersister

  @default_dir "/mnt/nas/sertantai-data/data/lat-archive"

  @doc "Archive directory in use."
  @spec dir(keyword()) :: String.t()
  def dir(opts \\ []) do
    Keyword.get(opts, :dir) ||
      Application.get_env(:sertantai_legal, :lat_archive_dir, @default_dir)
  end

  @doc "Write the law's current LAT to the archive; returns the file path (nil when it has no LAT)."
  @spec archive(String.t(), keyword()) :: {:ok, String.t() | nil} | {:error, String.t()}
  def archive(law_name, opts \\ []) do
    hash =
      case Repo.query!("SELECT lat_hash FROM legal_register WHERE name = $1", [law_name]) do
        %{rows: [[h]]} when is_binary(h) -> h
        _ -> "nohash"
      end

    %{rows: rows} =
      Repo.query!(
        "SELECT row_to_json(a)::text FROM legal_articles a WHERE law_name = $1 ORDER BY position",
        [law_name]
      )

    path = Path.join([dir(opts), law_name, hash <> ".jsonl.gz"])

    with {:rows, [_ | _]} <- {:rows, rows},
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, :zlib.gzip(Enum.map_join(rows, "\n", &hd/1) <> "\n")) do
      {:ok, path}
    else
      {:rows, []} ->
        {:ok, nil}

      {:error, reason} ->
        {:error, "archive failed for #{law_name} at #{path}: #{inspect(reason)}"}
    end
  rescue
    e -> {:error, "archive failed for #{law_name}: #{Exception.message(e)}"}
  end

  @doc """
  Archive (unless `archive: false`) and delete a law's LAT and its
  amendment annotations, recording a `discarded` event. Scoped LAT kept as
  enabling-extent evidence (#166) is refused unless `force: true`. Options: `dir`, `archive`, `source` (default "admin"),
  `actor`.
  """
  @spec discard(String.t(), String.t(), keyword()) ::
          {:ok,
           %{
             deleted: non_neg_integer(),
             annotations_deleted: non_neg_integer(),
             archive_ref: String.t() | nil
           }}
          | {:error, String.t()}
  def discard(law_name, reason, opts \\ []) do
    if "enabling_extent" in ((LatScope.get(law_name) || %{})["purposes"] || []) and
         not Keyword.get(opts, :force, false) do
      {:error,
       "#{law_name} holds scoped LAT kept as enabling-extent evidence (#166); pass force: true to discard"}
    else
      do_discard(law_name, reason, opts)
    end
  end

  defp do_discard(law_name, reason, opts) do
    archived =
      if Keyword.get(opts, :archive, true), do: archive(law_name, opts), else: {:ok, nil}

    with {:ok, ref} <- archived do
      Repo.transaction(fn ->
        LatPersister.set_event_context(
          op_id: Ecto.UUID.generate(),
          reason: reason,
          source: Keyword.get(opts, :source, "admin"),
          actor: Keyword.get(opts, :actor),
          archive_ref: ref
        )

        # Annotations are rebuilt from the XML on any re-parse: not archived.
        %{num_rows: ann} =
          Repo.query!("DELETE FROM amendment_annotations WHERE law_name = $1", [law_name])

        %{num_rows: n} = Repo.query!("DELETE FROM lat WHERE law_name = $1", [law_name])
        LatPersister.clear_event_context()
        %{deleted: n, annotations_deleted: ann, archive_ref: ref}
      end)
    end
  end
end
