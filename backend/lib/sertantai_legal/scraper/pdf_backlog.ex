defmodule SertantaiLegal.Scraper.PdfBacklog do
  @moduledoc """
  Backlog of laws that legislation.gov.uk publishes only as (usually scanned)
  PDFs, with no XML body to LAT-parse.

  When the LAT parse meets such a law, `capture/3` downloads its PDFs into
  `<dir>/<law_name>/` and appends a row to `<dir>/manifest.csv`. The backlog
  is worked off as an infrequent manual batch (OCR → LAT rows); see issue #165.

  The directory defaults to `data/pdf-backlog` (gitignored, included in the
  NAS backup) and can be set with `config :sertantai_legal, :pdf_backlog_dir`
  or the `:dir` option.

  Captures are idempotent: a PDF already in the backlog is not re-downloaded
  and gets no second manifest row.
  """

  alias SertantaiLegal.Scraper.LegislationGovUk.{BodyXml, Client}

  require Logger

  @manifest "manifest.csv"
  @header "law_name,pdf_url,file,bytes,captured_at"

  @doc "The backlog directory in use (`:dir` option, app config, or `data/pdf-backlog`)."
  @spec dir(keyword()) :: String.t()
  def dir(opts \\ []) do
    Keyword.get(opts, :dir) ||
      Application.get_env(:sertantai_legal, :pdf_backlog_dir, "data/pdf-backlog")
  end

  @doc """
  Download `pdf_urls` for `law_name` into the backlog. Returns the local file
  paths, or the first download error (earlier downloads are kept).
  """
  @spec capture(String.t(), [String.t()], keyword()) ::
          {:ok, [String.t()]} | {:error, String.t()}
  def capture(law_name, pdf_urls, opts \\ []) do
    root = dir(opts)
    File.mkdir_p!(Path.join(root, law_name))

    Enum.reduce_while(pdf_urls, {:ok, []}, fn url, {:ok, files} ->
      case capture_one(root, law_name, url) do
        {:ok, file} -> {:cont, {:ok, files ++ [file]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  @doc """
  For a body XML that yielded no LAT rows: queue its PDF alternatives, if any.
  Returns a human-readable reason and the captured files.
  """
  @spec queue_from_body(String.t(), String.t(), keyword()) :: {String.t(), [String.t()]}
  def queue_from_body(law_name, body_xml, opts \\ []) do
    case BodyXml.pdf_links(body_xml) do
      [] ->
        {"no XML body and no PDF alternative", []}

      urls ->
        case capture(law_name, urls, opts) do
          {:ok, files} -> {"no XML body; #{length(files)} PDF(s) queued to backlog", files}
          {:error, why} -> {"no XML body; #{why}", []}
        end
    end
  end

  defp capture_one(root, law_name, url) do
    rel = Path.join(law_name, Path.basename(URI.parse(url).path))
    file = Path.join(root, rel)

    if File.exists?(file) do
      {:ok, file}
    else
      download(root, law_name, url, rel, file)
    end
  end

  defp download(root, law_name, url, rel, file) do
    case Client.fetch_pdf(url) do
      {:ok, bytes} ->
        tmp = file <> ".part"
        File.write!(tmp, bytes)
        File.rename!(tmp, file)
        append_manifest(root, [law_name, url, rel, byte_size(bytes), now()])
        Logger.info("[PdfBacklog] #{law_name}: queued #{rel} (#{byte_size(bytes)} bytes)")
        {:ok, file}

      {:error, code, reason} ->
        {:error, "PDF download failed (#{code}): #{reason}"}
    end
  end

  defp append_manifest(root, fields) do
    path = Path.join(root, @manifest)
    unless File.exists?(path), do: File.write!(path, @header <> "\n")
    File.write!(path, Enum.join(fields, ",") <> "\n", [:append])
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601()
end
