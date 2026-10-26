defmodule SertantaiLegal.Scraper.SourceVersion do
  @moduledoc """
  A compile-time version of a set of source files (lat-refactor LR-25): a
  12-hex hash of each file's path and content. Used by `ParserVersion` (what
  a parse's output depends on) and `LabelVersion` (what a law's register and
  timeline depend on), so stored output made by older code shows as stale.

      use SertantaiLegal.Scraper.SourceVersion,
        patterns: ~w(lib/sertantai_legal/scraper/lat_parser.ex mix.lock)

  defines `current/0` and `files/0`. Patterns are globs relative to the
  backend root; each matched file is an `@external_resource`, so an edit
  recompiles the module. Any edit, whitespace included, changes the version.

  `deps: ~w(sweet_xml)` adds only those dependencies' `mix.lock` entries,
  not the whole lock: another dependency's bump leaves the version as it is
  (run time 2026-10-26: `ChangeVocabulary.Version` hashed all of `mix.lock`).
  """

  @root Path.expand("../../..", __DIR__)

  @doc "A 12-hex digest of `{path, content}` pairs, independent of their order."
  @spec digest([{String.t(), String.t()}]) :: String.t()
  def digest(pairs) do
    pairs
    |> Enum.sort()
    |> Enum.map(fn {path, content} -> [path, 0, content, 0] end)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end

  @doc "The files matched by `patterns`, relative to the backend root, sorted."
  @spec files([String.t()]) :: [String.t()]
  def files(patterns) do
    patterns
    |> Enum.flat_map(&Path.wildcard(Path.join(@root, &1)))
    |> Enum.map(&Path.relative_to(&1, @root))
    |> Enum.sort()
  end

  @doc "The digest of `files` as they are on disk."
  @spec of_files([String.t()]) :: String.t()
  def of_files(files), do: digest(Enum.map(files, &{&1, File.read!(Path.join(@root, &1))}))

  @doc """
  The named dependencies' entries in a `mix.lock` text, as
  `{"mix.lock#dep", entry}` pairs (sorted by dep) for `digest/1`.
  """
  @spec lock_entries(String.t(), [String.t()]) :: [{String.t(), String.t()}]
  def lock_entries(lock, deps) do
    for line <- String.split(lock, "\n"),
        [_, dep] <- [Regex.run(~r/^\s*"([a-z0-9_]+)":/, line)],
        dep in deps,
        do: {"mix.lock#" <> dep, String.trim(line)}
  end

  @doc "The digest of `files` as on disk, with the named deps' lock entries."
  @spec of_files([String.t()], [String.t()]) :: String.t()
  def of_files(files, []), do: of_files(files)

  def of_files(files, deps) do
    lock = File.read!(Path.join(@root, "mix.lock"))
    digest(Enum.map(files, &{&1, File.read!(Path.join(@root, &1))}) ++ lock_entries(lock, deps))
  end

  @doc "The absolute path of a backend-relative file."
  @spec path(String.t()) :: String.t()
  def path(file), do: Path.join(@root, file)

  defmacro __using__(opts) do
    quote bind_quoted: [
            patterns: Keyword.fetch!(opts, :patterns),
            deps: Keyword.get(opts, :deps, [])
          ] do
      @source_files SertantaiLegal.Scraper.SourceVersion.files(patterns)
      for f <- @source_files,
          do: @external_resource(SertantaiLegal.Scraper.SourceVersion.path(f))

      if deps != [],
        do: @external_resource(SertantaiLegal.Scraper.SourceVersion.path("mix.lock"))

      @source_version SertantaiLegal.Scraper.SourceVersion.of_files(@source_files, deps)

      @doc "The version this build was compiled from."
      @spec current() :: String.t()
      def current, do: @source_version

      @doc "The files the version covers, relative to the backend root."
      @spec files() :: [String.t()]
      def files, do: @source_files
    end
  end
end
