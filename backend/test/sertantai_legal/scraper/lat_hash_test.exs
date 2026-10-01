defmodule SertantaiLegal.Scraper.LatHashTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.LatHash

  @vectors "test/fixtures/lat_hash/vectors.json" |> File.read!() |> Jason.decode!()

  defp rows(vector) do
    Enum.map(vector["rows"], fn r -> Map.new(r, fn {k, v} -> {String.to_atom(k), v} end) end)
  end

  describe "shared vectors (fractalatai #62; pinned in fractalaw-core too)" do
    for name <- ~w(synthetic empty fixture_law) do
      test "#{name}" do
        v = Map.fetch!(@vectors, unquote(name))
        assert LatHash.hash(rows(v)) == v["lat_hash"]
        assert LatHash.struct_hash(rows(v)) == v["struct_hash"]
        assert length(v["rows"]) == v["row_count"]
      end
    end
  end

  describe "normalise/1" do
    test "collapses runs of every Unicode White_Space character, including NBSP and U+202F" do
      for cp <- [
            0x09,
            0x0A,
            0x0B,
            0x0C,
            0x0D,
            0x20,
            0x85,
            0xA0,
            0x1680,
            0x2000,
            0x2007,
            0x200A,
            0x2028,
            0x2029,
            0x202F,
            0x205F,
            0x3000
          ] do
        assert LatHash.normalise("a" <> <<cp::utf8>> <> <<cp::utf8>> <> "b") == "a b",
               "U+#{Integer.to_string(cp, 16)}"
      end
    end

    test "trims, keeps zero-width characters, and treats nil as empty" do
      assert LatHash.normalise("  a​b﻿  ") == "a​b﻿"
      assert LatHash.normalise(nil) == ""
    end

    test "applies NFC" do
      assert LatHash.normalise("é") == "é"
    end
  end

  describe "hash/1" do
    test "orders rows by section_id bytewise, whatever the input order" do
      a = %{section_id: "X:reg.10", sort_key: "2", text: "ten"}
      b = %{section_id: "X:reg.2", sort_key: "1", text: "two"}
      c = %{section_id: "X:Reg.3", sort_key: "3", text: "upper"}

      assert LatHash.hash([a, b, c]) == LatHash.hash([c, b, a])

      expected =
        :crypto.hash(:sha256, "X:Reg.3\t3\tupper\nX:reg.10\t2\tten\nX:reg.2\t1\ttwo\n")
        |> Base.encode16(case: :lower)

      assert LatHash.hash([a, b, c]) == expected
    end

    test "a sort_key change alone changes the hash; nil sort_key is empty" do
      row = %{section_id: "X:reg.1", sort_key: "0001", text: "t"}
      refute LatHash.hash([row]) == LatHash.hash([%{row | sort_key: "0002"}])
      assert LatHash.hash([%{row | sort_key: nil}]) == LatHash.hash([%{row | sort_key: ""}])
    end

    test "the empty law hashes to sha256(\"\")" do
      assert LatHash.hash([]) == LatHash.empty_hash()

      assert LatHash.empty_hash() ==
               "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
  end

  describe "struct_hash/1" do
    test "integers are plain decimal, nil is empty, strings are not normalised" do
      row = %{
        section_id: "X:reg.1",
        section_type: "article",
        depth: 1,
        position: 12,
        text: "ignored"
      }

      line =
        ["X:reg.1", "article", "", "1", "12"] ++ List.duplicate("", 14)

      expected =
        :crypto.hash(:sha256, Enum.join(line, "\t") <> "\n") |> Base.encode16(case: :lower)

      assert LatHash.struct_hash([row]) == expected
    end

    test "text and sort_key do not affect it; position does" do
      row = %{section_id: "X:reg.1", position: 1, text: "a", sort_key: "1"}

      assert LatHash.struct_hash([row]) ==
               LatHash.struct_hash([%{row | text: "b", sort_key: "2"}])

      refute LatHash.struct_hash([row]) == LatHash.struct_hash([%{row | position: 2}])
    end
  end

  describe "status_hash/1 (#167)" do
    test "SHA-256 over section_id TAB status LF, bytewise by section_id" do
      rows = [
        %{section_id: "L:s.2", status: "repealed"},
        %{section_id: "L:s.10", status: "in_force"}
      ]

      expected =
        :crypto.hash(:sha256, "L:s.10\tin_force\nL:s.2\trepealed\n")
        |> Base.encode16(case: :lower)

      assert LatHash.status_hash(rows) == expected
      assert LatHash.status_hash(Enum.reverse(rows)) == expected
    end

    test "nil while any row's status is not yet computed; empty hash with no rows" do
      assert LatHash.status_hash([%{section_id: "L:s.1", status: nil}]) == nil
      assert LatHash.status_hash([]) == LatHash.empty_hash()
    end
  end
end
