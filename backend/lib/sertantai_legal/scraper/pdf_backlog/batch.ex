defmodule SertantaiLegal.Scraper.PdfBacklog.Batch do
  @moduledoc """
  Manual batch over the PDF backlog (issue #165): turns each law's
  `transcript.md` into LAT rows through the standard pipeline.

  Per law folder (`<backlog>/<law_name>/`):
  - `*.pdf` — captured by `PdfBacklog.capture/3`
  - `transcript.md` — the law's text in `Transcript` markup (OCR / vision /
    human); the manual step
  - `body.xml` — generated CLML, kept for audit
  - `lat.json` — the last parse: time, transcript SHA-256, rows, QA warnings

  States: `:needs_transcript` → `:ready` → `:parsed` (`:stale` when the
  transcript changed after its last parse).

  The rows persist through `LatStagedParser.run_stages/5`, so they get the
  same section ids, extent refresh and annotation handling as XML-sourced LAT.
  """

  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.{LatParser, LatStagedParser, PdfBacklog}
  alias SertantaiLegal.Scraper.PdfBacklog.{Clml, Transcript}

  @type state :: :needs_transcript | :ready | :parsed | :stale

  @doc "Every law in the backlog with its PDFs and state."
  @spec status(keyword()) :: [%{law_name: String.t(), pdfs: [String.t()], state: state()}]
  def status(opts \\ []) do
    root = PdfBacklog.dir(opts)

    root
    |> File.ls()
    |> case do
      {:ok, entries} -> entries
      {:error, _} -> []
    end
    |> Enum.filter(&File.dir?(Path.join(root, &1)))
    |> Enum.sort()
    |> Enum.map(fn law ->
      folder = Path.join(root, law)
      pdfs = folder |> File.ls!() |> Enum.filter(&String.ends_with?(&1, ".pdf")) |> Enum.sort()
      %{law_name: law, pdfs: pdfs, state: state(folder)}
    end)
  end

  defp state(folder) do
    transcript = Path.join(folder, "transcript.md")
    record = Path.join(folder, "lat.json")

    cond do
      not File.exists?(transcript) ->
        :needs_transcript

      not File.exists?(record) ->
        :ready

      sha(File.read!(transcript)) == Jason.decode!(File.read!(record))["transcript_sha256"] ->
        :parsed

      true ->
        :stale
    end
  end

  @doc """
  Parse one law's transcript and (unless `dry_run: true`) persist its LAT.
  Returns the row count, QA warnings and whether it persisted.
  """
  @spec run(String.t(), keyword()) ::
          {:ok, %{rows: non_neg_integer(), qa: [String.t()], persisted: boolean()}}
          | {:error, String.t()}
  def run(law_name, opts \\ []) do
    folder = Path.join(PdfBacklog.dir(opts), law_name)
    path = Path.join(folder, "transcript.md")

    with {:ok, text} <- read_transcript(path),
         {:ok, transcript} <- Transcript.parse(text),
         {:ok, {law_id, type_code}} <- lookup_law(law_name) do
      xml = Clml.to_clml(transcript)
      qa = Transcript.qa(transcript)
      rows = length(LatParser.parse(xml, %{law_name: law_name, type_code: type_code}))
      File.write!(Path.join(folder, "body.xml"), xml)

      if Keyword.get(opts, :dry_run, false) do
        {:ok, %{rows: rows, qa: qa, persisted: false}}
      else
        persist(law_name, type_code, law_id, xml, folder, text, qa, rows)
      end
    end
  end

  defp persist(law_name, type_code, law_id, xml, folder, text, qa, rows) do
    {:ok, result} = LatStagedParser.run_stages(law_name, type_code, law_id, xml)

    case LatStagedParser.record_outcome(result) do
      {:parsed, _} ->
        record = %{
          parsed_at: DateTime.utc_now() |> DateTime.truncate(:second),
          transcript_sha256: sha(text),
          rows: result.lat.inserted,
          qa: qa
        }

        File.write!(Path.join(folder, "lat.json"), Jason.encode!(record, pretty: true))
        {:ok, %{rows: rows, qa: qa, persisted: true}}

      {:failed, error} ->
        {:error, error}
    end
  end

  defp read_transcript(path) do
    case File.read(path) do
      {:ok, text} -> {:ok, text}
      {:error, _} -> {:error, "no transcript at #{path}"}
    end
  end

  defp lookup_law(law_name) do
    case Repo.query("SELECT id::text, type_code FROM uk_lrt WHERE name = $1 LIMIT 1", [law_name]) do
      {:ok, %{rows: [[id, type_code]]}} -> {:ok, {id, type_code}}
      {:ok, %{rows: []}} -> {:error, "law not found in uk_lrt: #{law_name}"}
      {:error, err} -> {:error, "DB error: #{inspect(err)}"}
    end
  end

  defp sha(text), do: :crypto.hash(:sha256, text) |> Base.encode16(case: :lower)
end
