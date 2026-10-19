defmodule SertantaiLegal.Scraper.ParserVersion do
  @moduledoc """
  The version of the code a LAT parse's output depends on (lat-refactor
  LR-25, `SourceVersion`). Each `parsed` lat_event records it
  (`parser_version`), so a law parsed by older parser code shows as stale
  even with no new parse (LR-28 found 162 laws behind the parser after parser
  commits that no wave followed).

  The files are the modules the parse reaches (`LatParser`, its notes'
  `CommentaryParser`, the changes-feed effects that give rows their effect
  joins and territory, `LatScope` fragments, PDF transcripts), not Ash
  resources or fetch plumbing: an edit there doesn't change parse output.
  """

  use SertantaiLegal.Scraper.SourceVersion,
    patterns: ~w(
      lib/sertantai_legal/scraper/lat_parser.ex
      lib/sertantai_legal/scraper/lat_parser/*.ex
      lib/sertantai_legal/scraper/lat_staged_parser.ex
      lib/sertantai_legal/scraper/lat_scope.ex
      lib/sertantai_legal/scraper/lat_segments.ex
      lib/sertantai_legal/scraper/lat_territory.ex
      lib/sertantai_legal/scraper/lat_status.ex
      lib/sertantai_legal/scraper/territory.ex
      lib/sertantai_legal/scraper/effect_index.ex
      lib/sertantai_legal/scraper/effect_target.ex
      lib/sertantai_legal/scraper/provision_text.ex
      lib/sertantai_legal/scraper/effect_territory.ex
      lib/sertantai_legal/scraper/in_force_qualifier.ex
      lib/sertantai_legal/scraper/id_field.ex
      lib/sertantai_legal/scraper/commentary_parser.ex
      lib/sertantai_legal/scraper/note_pointer.ex
      lib/sertantai_legal/scraper/effect_kind.ex
      lib/sertantai_legal/scraper/legislation_gov_uk/changes_feed.ex
      lib/sertantai_legal/scraper/pdf_backlog/clml.ex
      lib/sertantai_legal/scraper/pdf_backlog/transcript.ex
      lib/sertantai_legal/legal/lat/transforms.ex
      lib/sertantai_legal/legal/lat/section_type.ex
      mix.lock
    )

  @doc "A 12-hex digest of `{path, content}` pairs, independent of their order."
  @spec digest([{String.t(), String.t()}]) :: String.t()
  defdelegate digest(pairs), to: SertantaiLegal.Scraper.SourceVersion
end
