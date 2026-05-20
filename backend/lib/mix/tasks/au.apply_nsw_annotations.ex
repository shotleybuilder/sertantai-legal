defmodule Mix.Tasks.Au.ApplyNswAnnotations do
  @moduledoc """
  Apply manually annotated NSW data from data/au-needs-number-nsw.md.

  Parses annotations: No NNN, [In Force], [Repealed], [not in seed].
  Updates existing records with number/source_url/status.
  Creates new records tagged [not in seed].
  """

  use Mix.Task

  alias SertantaiLegal.Legal.LegalRegister

  require Ash.Query

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")

    lines =
      "data/au-needs-number-nsw.md"
      |> File.read!()
      |> String.split("\n")
      |> Enum.filter(&(String.trim(&1) != ""))

    {updated, created, skipped, repealed_count, not_found} =
      Enum.reduce(lines, {0, 0, 0, 0, []}, fn line, acc ->
        process_line(String.trim_leading(line, "- "), acc)
      end)

    Mix.shell().info("""
    \nNSW annotation import complete:
      Updated: #{updated}
      Created (not in seed): #{created}
      Skipped: #{skipped}
      Repealed: #{repealed_count}
      Not found: #{length(not_found)}
    """)

    if length(not_found) > 0 do
      Mix.shell().info("Not found titles:")

      not_found
      |> Enum.reverse()
      |> Enum.each(&Mix.shell().info("  ? #{&1}"))
    end
  end

  defp process_line(line, {upd, cre, skip, rep, nf}) do
    number = extract_number(line)
    repealed? = String.contains?(line, "[Repealed]")
    in_force? = String.contains?(line, "[In Force]") or String.contains?(line, "[In force]")
    not_in_seed? = String.contains?(line, "[not in seed]")

    title = clean_title(line)
    year = extract_year(title)
    source_url = build_source_url(title, number, year, repealed?)

    live =
      cond do
        repealed? -> "✗ Repealed"
        in_force? -> "✔ In force"
        true -> nil
      end

    if not_in_seed? do
      create_record(title, number, year, source_url, live)
      {upd, cre + 1, skip, rep, nf}
    else
      case find_record(title) do
        {:ok, record} ->
          attrs = build_update_attrs(record, number, source_url, live)

          if map_size(attrs) > 0 do
            record |> Ash.Changeset.for_update(:update, attrs) |> Ash.update()
            rep_inc = if repealed?, do: 1, else: 0
            {upd + 1, cre, skip, rep + rep_inc, nf}
          else
            {upd, cre, skip + 1, rep, nf}
          end

        :not_found ->
          {upd, cre, skip + 1, rep, [title | nf]}
      end
    end
  end

  defp extract_number(line) do
    case Regex.run(~r/\bNo\s+(\d+\w?)\b/, line) do
      [_, n] -> n
      _ -> nil
    end
  end

  defp extract_year(title) do
    case Regex.run(~r/\b((?:19|20)\d\d)\b/, title) do
      [_, y] -> String.to_integer(y)
      _ -> nil
    end
  end

  defp clean_title(line) do
    line
    |> String.replace(
      ~r/\s*\[(?:Repealed|In [Ff]orce|not in seed|title missed spelling|\?)\]\s*/,
      ""
    )
    |> String.replace(~r/\s*\(uncommenced\)\s*/, "")
    |> String.replace(~r/\s+No\s+\d+\w?\s*$/, "")
    |> String.trim()
  end

  defp build_source_url(title, number, year, repealed?)
       when not is_nil(number) and not is_nil(year) do
    type_prefix =
      cond do
        Regex.match?(~r/\bAct\b/, title) -> "act"
        true -> "sl"
      end

    padded = String.pad_leading(number, 3, "0")
    status_path = if repealed?, do: "repealed", else: "inforce"

    "https://legislation.nsw.gov.au/view/html/#{status_path}/current/#{type_prefix}-#{year}-#{padded}"
  end

  defp build_source_url(_title, _number, _year, _repealed?), do: nil

  defp find_record(title) do
    # Try exact match first
    case LegalRegister
         |> Ash.Query.filter(country == "au" and jurisdiction == "nsw" and title_en == ^title)
         |> Ash.read() do
      {:ok, [r | _]} ->
        {:ok, r}

      _ ->
        # Fuzzy: try first 30 chars ILIKE
        prefix = String.slice(title, 0, 30)

        case LegalRegister
             |> Ash.Query.filter(
               country == "au" and jurisdiction == "nsw" and
                 fragment("? ILIKE ?", title_en, ^"#{prefix}%")
             )
             |> Ash.read() do
          {:ok, [r | _]} -> {:ok, r}
          _ -> :not_found
        end
    end
  end

  defp create_record(title, number, year, source_url, live) do
    type_code =
      cond do
        Regex.match?(~r/\bAct\b/, title) -> "act"
        Regex.match?(~r/\bRegulation\b/, title) -> "reg"
        Regex.match?(~r/\bRules?\b/, title) -> "rule"
        true -> "li"
      end

    slug =
      title
      |> String.downcase()
      |> String.replace(~r/[^a-z0-9]+/, "_")
      |> String.trim("_")
      |> String.slice(0, 70)

    attrs =
      %{
        country: "au",
        jurisdiction: "nsw",
        title_en: title,
        type_code: type_code,
        name: "AU_nsw_#{slug}",
        making_review: "making"
      }
      |> maybe_put(:year, year)
      |> maybe_put(:number, number)
      |> maybe_put(:source_url, source_url)
      |> maybe_put(:live, live)

    case LegalRegister |> Ash.Changeset.for_create(:create, attrs) |> Ash.create() do
      {:ok, _} -> Mix.shell().info("  + #{title}")
      {:error, _} -> Mix.shell().error("  ! CREATE FAIL: #{title}")
    end
  end

  defp build_update_attrs(record, number, source_url, live) do
    %{}
    |> maybe_put(:number, if(number && is_nil(record.number), do: number))
    |> maybe_put(:source_url, if(source_url && is_nil(record.source_url), do: source_url))
    |> maybe_put(:live, live)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)
end
