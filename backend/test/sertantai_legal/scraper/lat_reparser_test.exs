defmodule SertantaiLegal.Scraper.LatReparserTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatReparser

  # LatReparser goes through LatStagedParser so a scoped law (#166) is never
  # re-widened to its whole body by the admin re-parse.
  describe "reparse/2" do
    test "delegates to the staged parser and returns its result" do
      parse = fn "UK_ukpga_2006_46" ->
        {:ok,
         %{
           law_name: "UK_ukpga_2006_46",
           lat: %{inserted: 10, deleted: 12},
           annotations: %{inserted: 3},
           duration_ms: 5,
           has_errors: false
         }}
      end

      assert {:ok, %{lat: %{inserted: 10}, annotations: %{inserted: 3}, duration_ms: 5}} =
               LatReparser.reparse("UK_ukpga_2006_46", parse)
    end

    test "a staged result with errors is an error" do
      parse = fn _ -> {:ok, %{has_errors: true, error: "fetch_body: 404", lat: %{}}} end

      assert LatReparser.reparse("UK_ukpga_2006_46", parse) == {:error, "fetch_body: 404"}
    end

    test "a staged error passes through" do
      parse = fn _ -> {:error, "Law not found in uk_lrt: X"} end

      assert LatReparser.reparse("X", parse) == {:error, "Law not found in uk_lrt: X"}
    end
  end
end
