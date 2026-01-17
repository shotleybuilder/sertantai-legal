# Script to fix corrupted duty_type data format
#
# The duty_type column should be JSONB maps like {"values": ["a", "b"]}
# but was imported as JSONB strings containing CSV like "a,\"b,c\",d"
#
# This script converts the CSV strings to proper JSONB format.
#
# Usage:
#   cd backend
#   mix run ../scripts/data/fix_duty_type_format.exs
#   mix run ../scripts/data/fix_duty_type_format.exs --dry-run

defmodule DutyTypeFormatFixer do
  alias SertantaiLegal.Repo

  def run(dry_run \\ false) do
    IO.puts("\n=== Fixing duty_type format ===")
    IO.puts("Mode: #{if dry_run, do: "DRY RUN", else: "LIVE"}\n")

    # Get records with invalid duty_type format (JSONB string type, not object)
    # Use #>> '{}' to extract the inner string value
    query = """
    SELECT id, name, duty_type #>> '{}' as csv_string
    FROM uk_lrt
    WHERE duty_type IS NOT NULL
      AND jsonb_typeof(duty_type) = 'string'
    """

    {:ok, result} = Repo.query(query)
    records = result.rows

    IO.puts("Found #{length(records)} records with invalid duty_type format\n")

    if dry_run do
      # Show sample of what would be fixed
      records
      |> Enum.take(5)
      |> Enum.each(fn [_id, name, csv_string] ->
        values = parse_csv_values(csv_string)
        IO.puts("#{name}:")
        IO.puts("  CSV:    #{inspect(csv_string)}")
        IO.puts("  Values: #{inspect(values)}")
        IO.puts("")
      end)

      IO.puts("... (showing first 5 of #{length(records)})")
    else
      # Fix all records
      fixed_count =
        records
        |> Enum.chunk_every(100)
        |> Enum.reduce(0, fn batch, acc ->
          count = fix_batch(batch)
          IO.write(".")
          acc + count
        end)

      IO.puts("\n\nFixed #{fixed_count} records")
    end

    show_summary()
  end

  defp fix_batch(records) do
    Enum.reduce(records, 0, fn [id, _name, csv_string], count ->
      values = parse_csv_values(csv_string)
      jsonb = Jason.encode!(%{"values" => values})

      # Use raw SQL to update since Ash can't read the corrupted data
      update_query = """
      UPDATE uk_lrt
      SET duty_type = $1::jsonb
      WHERE id = $2
      """

      case Repo.query(update_query, [jsonb, id]) do
        {:ok, _} -> count + 1
        {:error, _} -> count
      end
    end)
  end

  # Parse CSV with quoted values
  # Input: "Responsibility,\"Enactment, Citation\",Amendment"
  # Output: ["Responsibility", "Enactment, Citation", "Amendment"]
  defp parse_csv_values(nil), do: []
  defp parse_csv_values(""), do: []

  defp parse_csv_values(csv_string) when is_binary(csv_string) do
    csv_string
    |> String.trim()
    |> parse_csv_recursive([])
    |> Enum.reverse()
    |> Enum.reject(&(&1 == ""))
  end

  defp parse_csv_recursive("", acc), do: acc

  defp parse_csv_recursive(<<"\"", rest::binary>>, acc) do
    # Quoted value - find closing quote
    {value, remaining} = find_closing_quote(rest, "")
    # Skip comma after quoted value if present
    remaining = String.replace_prefix(remaining, ",", "")
    parse_csv_recursive(remaining, [value | acc])
  end

  defp parse_csv_recursive(<<",", rest::binary>>, acc) do
    # Skip leading commas (handles empty values between commas)
    parse_csv_recursive(rest, acc)
  end

  defp parse_csv_recursive(str, acc) do
    # Unquoted value - read until comma or end
    case String.split(str, ",", parts: 2) do
      [value, rest] -> parse_csv_recursive(rest, [String.trim(value) | acc])
      [value] -> [String.trim(value) | acc]
    end
  end

  defp find_closing_quote(<<"\"", rest::binary>>, value) do
    # Found closing quote
    {value, rest}
  end

  defp find_closing_quote(<<char::utf8, rest::binary>>, value) do
    find_closing_quote(rest, value <> <<char::utf8>>)
  end

  defp find_closing_quote("", value) do
    # No closing quote found, return what we have
    {value, ""}
  end

  defp show_summary do
    query = """
    SELECT
      COUNT(*) FILTER (WHERE duty_type IS NULL) as null_count,
      COUNT(*) FILTER (WHERE duty_type IS NOT NULL AND jsonb_typeof(duty_type) = 'object') as valid_count,
      COUNT(*) FILTER (WHERE duty_type IS NOT NULL AND jsonb_typeof(duty_type) = 'string') as invalid_count
    FROM uk_lrt
    """

    {:ok, result} = Repo.query(query)
    [[null_count, valid_count, invalid_count]] = result.rows

    IO.puts("\n=== Summary ===")
    IO.puts("Records with NULL duty_type: #{null_count}")
    IO.puts("Records with valid JSONB object: #{valid_count}")
    IO.puts("Records with JSONB string (invalid): #{invalid_count}")
  end
end

# Parse args
dry_run = "--dry-run" in System.argv()

DutyTypeFormatFixer.run(dry_run)
