defmodule SertantaiLegal.Scraper.ParserVersion do
  @moduledoc """
  The version of the code a LAT parse's output depends on (lat-refactor
  LR-25): a hash of the parser's source files and `mix.lock`, taken at
  compile time. Each `parsed` lat_event records it (`parser_version`), so a
  law parsed by older parser code shows as stale even with no new parse (LR-28
  found 162 laws behind the parser after parser commits that no wave
  followed).

  The files are the modules the parse reaches (`LatParser`, its notes'
  `CommentaryParser`, the changes-feed effects that give rows their effect
  joins and territory, `LatScope` fragments, PDF transcripts), not Ash
  resources or fetch plumbing: an edit there doesn't change parse output.
  Any edit to a listed file, whitespace included, changes the version —
  conservative by design.
  """

  defmodule Digest do
    @moduledoc false
    # compiled before the version is taken, so the version can use it
    def of(pairs) do
      pairs
      |> Enum.sort()
      |> Enum.map(fn {path, content} -> [path, 0, content, 0] end)
      |> then(&:crypto.hash(:sha256, &1))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)
    end
  end

  @root Path.expand("../../..", __DIR__)

  @patterns ~w(
    lib/sertantai_legal/scraper/lat_parser.ex
    lib/sertantai_legal/scraper/lat_parser/*.ex
    lib/sertantai_legal/scraper/lat_staged_parser.ex
    lib/sertantai_legal/scraper/lat_scope.ex
    lib/sertantai_legal/scraper/lat_segments.ex
    lib/sertantai_legal/scraper/lat_territory.ex
    lib/sertantai_legal/scraper/lat_status.ex
    lib/sertantai_legal/scraper/territory.ex
    lib/sertantai_legal/scraper/effect_index.ex
    lib/sertantai_legal/scraper/effect_territory.ex
    lib/sertantai_legal/scraper/in_force_qualifier.ex
    lib/sertantai_legal/scraper/id_field.ex
    lib/sertantai_legal/scraper/commentary_parser.ex
    lib/sertantai_legal/scraper/amendment_note.ex
    lib/sertantai_legal/scraper/change_facts.ex
    lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
    lib/sertantai_legal/scraper/pdf_backlog/clml.ex
    lib/sertantai_legal/scraper/pdf_backlog/transcript.ex
    lib/sertantai_legal/legal/lat/transforms.ex
    lib/sertantai_legal/legal/lat/section_type.ex
    mix.lock
  )

  @files @patterns
         |> Enum.flat_map(&Path.wildcard(Path.join(@root, &1)))
         |> Enum.map(&Path.relative_to(&1, @root))
         |> Enum.sort()

  for f <- @files, do: @external_resource(Path.join(@root, f))

  @version Digest.of(Enum.map(@files, &{&1, File.read!(Path.join(@root, &1))}))

  @doc "A 12-hex digest of `{path, content}` pairs, independent of their order."
  @spec digest([{String.t(), String.t()}]) :: String.t()
  def digest(pairs), do: Digest.of(pairs)

  @doc "The parser version this build was compiled from."
  @spec current() :: String.t()
  def current, do: @version

  @doc "The files the version covers, relative to the backend root."
  @spec files() :: [String.t()]
  def files, do: @files
end
