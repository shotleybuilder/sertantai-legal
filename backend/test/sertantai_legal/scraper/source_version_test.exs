defmodule SertantaiLegal.Scraper.SourceVersionTest do
  use ExUnit.Case, async: false

  alias SertantaiLegal.Scraper.SourceVersion

  @lock ~S"""
  %{
    "jason": {:hex, :jason, "1.4.5", "aaa", [:mix], [], "hexpm", "bbb"},
    "phoenix": {:hex, :phoenix, "1.8.0", "ccc", [:mix], [], "hexpm", "ddd"},
    "sweet_xml": {:hex, :sweet_xml, "0.7.5", "eee", [:mix], [], "hexpm", "fff"},
  }
  """

  test "only the named dependencies' lock entries, so another dependency's bump changes nothing" do
    entries = SourceVersion.lock_entries(@lock, ~w(sweet_xml jason))
    assert Enum.map(entries, &elem(&1, 0)) == ["mix.lock#jason", "mix.lock#sweet_xml"]

    bumped = String.replace(@lock, ~s("1.8.0"), ~s("1.8.1"))
    assert SourceVersion.lock_entries(bumped, ~w(sweet_xml jason)) == entries

    xml = String.replace(@lock, ~s("0.7.5"), ~s("0.7.6"))
    refute SourceVersion.lock_entries(xml, ~w(sweet_xml jason)) == entries
  end

  test "a file added under a pattern after compiling: not fresh, so Mix recompiles the module (#193)" do
    dir = Path.join("tmp", "source_version_#{System.unique_integer([:positive])}")
    File.mkdir_p!(SourceVersion.path(dir))
    on_exit(fn -> File.rm_rf!(SourceVersion.path(dir)) end)
    File.write!(SourceVersion.path(Path.join(dir, "a.ex")), "a")

    mod = :"Elixir.SourceVersionFresh#{System.unique_integer([:positive])}"

    Code.compile_quoted(
      quote do
        defmodule unquote(mod) do
          use SertantaiLegal.Scraper.SourceVersion, patterns: [unquote(dir) <> "/*.ex"]
        end
      end
    )

    assert mod.files() == [Path.join(dir, "a.ex")]
    assert mod.fresh?() and not mod.__mix_recompile__?()

    File.write!(SourceVersion.path(Path.join(dir, "b.ex")), "b")
    refute mod.fresh?()
    assert mod.__mix_recompile__?()
  end
end
