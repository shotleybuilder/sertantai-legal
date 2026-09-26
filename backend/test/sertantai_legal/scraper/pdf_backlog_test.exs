defmodule SertantaiLegal.Scraper.PdfBacklogTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LegislationGovUk.{BodyXml, Client}
  alias SertantaiLegal.Scraper.PdfBacklog

  @no_body File.read!("test/fixtures/legislation_gov_uk/body_uksi_1979_791_no_body.xml")
  @pdf_url "http://www.legislation.gov.uk/uksi/1979/791/pdfs/uksi_19790791_en.pdf"

  describe "BodyXml.pdf_links/1" do
    test "returns the PDF alternatives of a no-body law" do
      assert BodyXml.pdf_links(@no_body) == [@pdf_url]
    end

    test "returns [] when there are no alternatives or the XML is unparseable" do
      assert BodyXml.pdf_links("<Legislation/>") == []
      assert BodyXml.pdf_links("not xml") == []
    end
  end

  describe "capture/3" do
    setup do
      dir = Path.join(System.tmp_dir!(), "pdf-backlog-#{System.unique_integer([:positive])}")
      on_exit(fn -> File.rm_rf!(dir) end)

      Req.Test.stub(Client, fn conn ->
        send(self(), {:fetched, conn.request_path})

        conn
        |> Plug.Conn.put_resp_content_type("application/pdf")
        |> Plug.Conn.send_resp(200, "%PDF-1.4 scanned")
      end)

      %{dir: dir}
    end

    test "downloads each PDF into the law's folder and adds a manifest row", %{dir: dir} do
      assert {:ok, [file]} = PdfBacklog.capture("UK_uksi_1979_791", [@pdf_url], dir: dir)

      assert file == Path.join([dir, "UK_uksi_1979_791", "uksi_19790791_en.pdf"])
      assert File.read!(file) == "%PDF-1.4 scanned"

      assert [header, row] = dir |> Path.join("manifest.csv") |> File.read!() |> lines()
      assert header == "law_name,pdf_url,file,bytes,captured_at"

      assert row =~
               ~r/^UK_uksi_1979_791,#{Regex.escape(@pdf_url)},UK_uksi_1979_791\/uksi_19790791_en.pdf,16,/
    end

    test "is idempotent: a second capture neither re-downloads nor duplicates the row",
         %{dir: dir} do
      {:ok, _} = PdfBacklog.capture("UK_uksi_1979_791", [@pdf_url], dir: dir)
      assert_received {:fetched, _}

      assert {:ok, [_]} = PdfBacklog.capture("UK_uksi_1979_791", [@pdf_url], dir: dir)
      refute_received {:fetched, _}

      assert [_header, _row] = dir |> Path.join("manifest.csv") |> File.read!() |> lines()
    end

    test "a failed download is an error and leaves no file", %{dir: dir} do
      Req.Test.stub(Client, &Plug.Conn.send_resp(&1, 404, "Not found"))

      assert {:error, reason} = PdfBacklog.capture("UK_uksi_1979_791", [@pdf_url], dir: dir)
      assert reason =~ "404"
      refute File.exists?(Path.join([dir, "UK_uksi_1979_791", "uksi_19790791_en.pdf"]))
    end
  end

  defp lines(text), do: String.split(text, "\n", trim: true)
end
