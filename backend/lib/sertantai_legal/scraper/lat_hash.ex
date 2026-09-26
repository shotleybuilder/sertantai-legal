defmodule SertantaiLegal.Scraper.LatHash do
  @moduledoc """
  Content hash of a law's LAT, shared with fractalaw (fractalatai #62) so the
  hub can tell which laws it holds a stale copy of.

  Contract (fractalaw implements the same; shared vectors in
  `test/fixtures/lat_hash/vectors.json`):

  - rows: every row the LAT queryable serves for the law (the `lat` view,
    including empty-text structural rows), ordered by `section_id` bytewise
  - line: `section_id <TAB> sort_key <TAB> normalise(text) <LF>`
    (`sort_key` as-is; nil → "")
  - `normalise/1`: Unicode NFC, collapse runs of the Unicode White_Space set
    to one U+0020, trim; nil → ""
  - `lat_hash`: lowercase hex SHA-256 of the UTF-8 concatenation

  `struct_hash/1` (Jason, 2026-09-26) covers the structural columns
  `lat_hash` does not: same rows and order; line = `section_id` then TAB +
  each of `struct_columns/0` as-is (nil → "", integers plain decimal,
  strings not normalised) and LF.

  This module is the pure reference implementation; the SQL function
  `lat_hash_for()` computes the same for the trigger-maintained
  `legal_register.lat_hash` (see `LatHash.Query`).
  """

  # Unicode White_Space, spelled out: regex `\\s` differs between engines
  # (PostgreSQL's misses U+00A0, U+1680, U+2007 and U+202F).
  @whitespace_class "[\\x{0009}-\\x{000D}\\x{0020}\\x{0085}\\x{00A0}\\x{1680}\\x{2000}-\\x{200A}\\x{2028}\\x{2029}\\x{202F}\\x{205F}\\x{3000}]"

  @struct_columns ~w(section_type hierarchy_path depth position part chapter heading_group
                     provision paragraph sub_paragraph schedule extent_code language
                     amendment_count modification_count commencement_count extent_count
                     editorial_count)a

  @doc "The structural columns in `struct_hash` line order."
  @spec struct_columns() :: [atom()]
  def struct_columns, do: @struct_columns

  @doc "Normalise provision text for hashing (NFC, collapse White_Space, trim)."
  @spec normalise(String.t() | nil) :: String.t()
  def normalise(nil), do: ""

  def normalise(text) when is_binary(text) do
    text
    |> :unicode.characters_to_nfc_binary()
    |> String.replace(ws_run(), " ")
    |> String.trim_leading(" ")
    |> String.trim_trailing(" ")
  end

  @doc "`lat_hash` of rows with `section_id`, `sort_key` and `text` (any order)."
  @spec hash([%{section_id: String.t(), sort_key: String.t() | nil, text: String.t() | nil}]) ::
          String.t()
  def hash(rows) do
    rows
    |> Enum.sort_by(& &1.section_id)
    |> Enum.map(&[&1.section_id, ?\t, &1.sort_key || "", ?\t, normalise(&1.text), ?\n])
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  @doc "`struct_hash` of rows (maps with `section_id` and any `struct_columns/0`; missing = nil)."
  @spec struct_hash([map()]) :: String.t()
  def struct_hash(rows) do
    rows
    |> Enum.sort_by(& &1.section_id)
    |> Enum.map(fn row ->
      [row.section_id, Enum.map(@struct_columns, &[?\t, value(Map.get(row, &1))]), ?\n]
    end)
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp value(nil), do: ""
  defp value(v) when is_integer(v), do: Integer.to_string(v)
  defp value(v) when is_binary(v), do: v
  defp value(v), do: to_string(v)

  @doc "`lat_hash` of a law with no LAT rows: SHA-256 of the empty string."
  @spec empty_hash() :: String.t()
  def empty_hash, do: hash([])

  defp ws_run, do: Regex.compile!(@whitespace_class <> "+", "u")
end
