defmodule SertantaiLegal.Scraper.PdfBacklog.BatchTest do
  use SertantaiLegal.DataCase

  alias SertantaiLegal.Legal.LegalRegister
  alias SertantaiLegal.Repo
  alias SertantaiLegal.Scraper.PdfBacklog.Batch

  setup do
    dir = Path.join(System.tmp_dir!(), "pdf-backlog-#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(dir) end)

    name = "UK_uksi_1979_#{System.unique_integer([:positive])}"

    LegalRegister
    |> Ash.Changeset.for_create(:create, %{
      country: "uk",
      name: name,
      title_en: "Test Regulations",
      type_code: "uksi",
      year: 1979,
      number: "791"
    })
    |> Ash.create!()

    File.mkdir_p!(Path.join(dir, name))
    File.write!(Path.join([dir, name, "scan.pdf"]), "%PDF")

    %{dir: dir, name: name}
  end

  defp write_transcript(dir, name, body) do
    File.write!(
      Path.join([dir, name, "transcript.md"]),
      "---\nlaw_name: #{name}\nextent: E+W+S\n---\n" <> body
    )
  end

  defp lat_count(name) do
    %{rows: [[n]]} = Repo.query!("SELECT count(*) FROM lat WHERE law_name = $1", [name])
    n
  end

  test "status: a law without a transcript needs one", %{dir: dir, name: name} do
    assert [%{law_name: ^name, state: :needs_transcript, pdfs: ["scan.pdf"]}] =
             Batch.status(dir: dir)
  end

  test "dry run parses and reports but persists nothing", %{dir: dir, name: name} do
    write_transcript(dir, name, "1.—(1) One.\n(2) Two.\n2. Three.\n")

    assert {:ok, %{rows: 4, qa: [], persisted: false}} = Batch.run(name, dir: dir, dry_run: true)
    assert lat_count(name) == 0
    assert [%{state: :ready}] = Batch.status(dir: dir)
  end

  test "run persists LAT via the standard pipeline and records the parse", %{dir: dir, name: name} do
    write_transcript(dir, name, "1.—(1) One.\n(3) Three.\n")

    assert {:ok, %{rows: 3, persisted: true, qa: ["reg.1: paragraph (3) follows (1)"]}} =
             Batch.run(name, dir: dir)

    assert lat_count(name) == 3
    assert File.exists?(Path.join([dir, name, "body.xml"]))
    assert [%{state: :parsed}] = Batch.status(dir: dir)

    # Editing the transcript makes the law ready to re-run.
    write_transcript(dir, name, "1.—(1) One.\n(2) Two.\n")
    assert [%{state: :stale}] = Batch.status(dir: dir)
  end

  test "a law with no transcript cannot run", %{dir: dir, name: name} do
    assert {:error, msg} = Batch.run(name, dir: dir)
    assert msg =~ "no transcript"
  end
end
