defmodule SertantaiLegal.Scraper.LatParser.Diagnostics do
  @moduledoc """
  Post-parse diagnostic checks for LAT rows.

  Validates that parsed legislation hasn't tripped over a novel or
  unencountered legal structure. Run after `LatParser.parse/2` to catch
  anomalies before persisting.

  ## Usage

      rows = LatParser.parse(xml, context)
      case Diagnostics.validate(rows) do
        {:ok, []} -> # clean parse
        {:ok, warnings} -> # parse succeeded but has warnings worth reviewing
        {:error, errors} -> # critical issues that should block persistence
      end

  ## Checks

  - **structural_blob** — Part/Chapter/Schedule rows with large text (>1KB)
    when child section rows exist, indicating text duplication survived
  - **text_overlap** — structural row text that overlaps significantly with
    child section text (>50% overlap)
  - **empty_sections** — section-level rows with no text content
  - **duplicate_section_ids** — multiple rows sharing the same section_id
  - **text_size_outlier** — any single row with text >50KB
  - **missing_provisions** — laws with structural rows but zero section-level rows
  - **novel_elements** — unknown XML elements encountered during parsing
  """

  @structural_types ~w(part chapter schedule)
  @section_types ~w(section sub_section article sub_article paragraph sub_paragraph)
  @all_known_types @structural_types ++
                     @section_types ++ ~w(title heading table note signed commencement)

  @structural_blob_threshold 1_000
  @text_size_outlier_threshold 50_000
  @overlap_warning_threshold 0.5

  @type warning :: %{
          check: atom(),
          severity: :warning | :error,
          message: String.t(),
          detail: map()
        }

  @doc """
  Run all diagnostic checks on parsed LAT rows.

  Returns `{:ok, warnings}` when all critical checks pass (warnings may be
  non-empty), or `{:error, errors}` when critical issues are found.
  """
  @spec validate([map()]) :: {:ok, [warning()]} | {:error, [warning()]}
  def validate(rows) when is_list(rows) do
    warnings =
      List.flatten([
        check_structural_blobs(rows),
        check_text_overlap(rows),
        check_empty_sections(rows),
        check_duplicate_section_ids(rows),
        check_text_size_outliers(rows),
        check_missing_provisions(rows),
        check_unknown_section_types(rows)
      ])

    errors = Enum.filter(warnings, &(&1.severity == :error))

    if errors == [] do
      {:ok, warnings}
    else
      {:error, errors}
    end
  end

  @doc """
  Returns a summary map of parse quality metrics for a set of LAT rows.
  Useful for dashboard display and corpus-wide reporting.
  """
  @spec summary([map()]) :: map()
  def summary(rows) when is_list(rows) do
    type_counts =
      rows
      |> Enum.group_by(& &1.section_type)
      |> Map.new(fn {type, group} -> {type, length(group)} end)

    structural_rows = Enum.filter(rows, &(&1.section_type in @structural_types))
    section_rows = Enum.filter(rows, &(&1.section_type in @section_types))

    structural_text_bytes =
      structural_rows
      |> Enum.map(fn r -> byte_size(r.text || "") end)
      |> Enum.sum()

    section_text_bytes =
      section_rows
      |> Enum.map(fn r -> byte_size(r.text || "") end)
      |> Enum.sum()

    total_text_bytes = Enum.map(rows, fn r -> byte_size(r.text || "") end) |> Enum.sum()

    max_row =
      rows
      |> Enum.max_by(fn r -> byte_size(r.text || "") end, fn -> nil end)

    %{
      total_rows: length(rows),
      structural_rows: length(structural_rows),
      section_rows: length(section_rows),
      type_counts: type_counts,
      structural_text_bytes: structural_text_bytes,
      section_text_bytes: section_text_bytes,
      total_text_bytes: total_text_bytes,
      structural_text_pct:
        if(total_text_bytes > 0,
          do: Float.round(structural_text_bytes / total_text_bytes * 100, 1),
          else: 0.0
        ),
      max_row_text_bytes: if(max_row, do: byte_size(max_row.text || ""), else: 0),
      max_row_section_id: if(max_row, do: max_row[:section_id], else: nil)
    }
  end

  # ── Individual Checks ──────────────────────────────────────────

  @doc false
  def check_structural_blobs(rows) do
    structural = Enum.filter(rows, &(&1.section_type in @structural_types))
    has_sections = Enum.any?(rows, &(&1.section_type in @section_types))

    if has_sections do
      structural
      |> Enum.filter(fn r ->
        text_len = byte_size(r.text || "")
        text_len > @structural_blob_threshold
      end)
      |> Enum.map(fn r ->
        %{
          check: :structural_blob,
          severity: :error,
          message:
            "#{r.section_type} row #{r[:section_id] || r[:citation] || "?"} has #{byte_size(r.text || "")} bytes — expected header-only text",
          detail: %{
            section_id: r[:section_id],
            section_type: r.section_type,
            text_bytes: byte_size(r.text || ""),
            text_preview: String.slice(r.text || "", 0, 200)
          }
        }
      end)
    else
      []
    end
  end

  @doc false
  def check_text_overlap(rows) do
    structural = Enum.filter(rows, &(&1.section_type in @structural_types))

    Enum.flat_map(structural, fn struct_row ->
      children = child_rows_for(rows, struct_row)

      if children != [] and (struct_row.text || "") != "" do
        child_text = children |> Enum.map(& &1.text) |> Enum.reject(&is_nil/1) |> Enum.join(" ")
        overlap = text_overlap_ratio(struct_row.text, child_text)

        if overlap > @overlap_warning_threshold do
          [
            %{
              check: :text_overlap,
              severity: :warning,
              message:
                "#{struct_row.section_type} #{struct_row[:section_id]} has #{Float.round(overlap * 100, 0)}% text overlap with child sections",
              detail: %{
                section_id: struct_row[:section_id],
                overlap_pct: Float.round(overlap * 100, 1),
                structural_bytes: byte_size(struct_row.text || ""),
                child_count: length(children)
              }
            }
          ]
        else
          []
        end
      else
        []
      end
    end)
  end

  @doc false
  # Only flag leaf-level provisions (paragraph, sub_paragraph) as empty.
  # Sections/sub_sections with nil text often have children (structural dedup by design).
  # [Repealed]/[Revoked] markers are not empty.
  @leaf_types ~w(paragraph sub_paragraph)
  def check_empty_sections(rows) do
    rows
    |> Enum.filter(fn r ->
      r.section_type in @leaf_types and (r.text == nil or r.text == "")
    end)
    |> Enum.map(fn r ->
      %{
        check: :empty_section,
        severity: :warning,
        message: "#{r.section_type} #{r[:section_id] || r[:citation]} has no text",
        detail: %{section_id: r[:section_id], section_type: r.section_type}
      }
    end)
  end

  @doc false
  def check_duplicate_section_ids(rows) do
    rows
    |> Enum.map(& &1[:section_id])
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.filter(fn {_id, count} -> count > 1 end)
    |> Enum.map(fn {id, count} ->
      %{
        check: :duplicate_section_id,
        severity: :warning,
        message: "section_id #{id} appears #{count} times",
        detail: %{section_id: id, count: count}
      }
    end)
  end

  @doc false
  def check_text_size_outliers(rows) do
    rows
    |> Enum.filter(fn r -> byte_size(r.text || "") > @text_size_outlier_threshold end)
    |> Enum.map(fn r ->
      %{
        check: :text_size_outlier,
        severity: :warning,
        message:
          "#{r.section_type} #{r[:section_id]} has #{byte_size(r.text || "")} bytes (>#{@text_size_outlier_threshold})",
        detail: %{
          section_id: r[:section_id],
          section_type: r.section_type,
          text_bytes: byte_size(r.text || "")
        }
      }
    end)
  end

  @doc false
  def check_missing_provisions(rows) do
    has_structural = Enum.any?(rows, &(&1.section_type in @structural_types))
    has_sections = Enum.any?(rows, &(&1.section_type in @section_types))

    if has_structural and not has_sections do
      [
        %{
          check: :missing_provisions,
          severity: :error,
          message:
            "Law has #{length(Enum.filter(rows, &(&1.section_type in @structural_types)))} structural rows but zero section-level rows",
          detail: %{total_rows: length(rows)}
        }
      ]
    else
      []
    end
  end

  @doc false
  def check_unknown_section_types(rows) do
    rows
    |> Enum.map(& &1.section_type)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.reject(&(&1 in @all_known_types))
    |> Enum.map(fn type ->
      count = Enum.count(rows, &(&1.section_type == type))

      %{
        check: :unknown_section_type,
        severity: :warning,
        message: "Unknown section_type \"#{type}\" (#{count} rows)",
        detail: %{section_type: type, count: count}
      }
    end)
  end

  # ── Helpers ────────────────────────────────────────────────────

  # Find section-level rows that belong to a structural container
  defp child_rows_for(rows, struct_row) do
    Enum.filter(rows, fn r ->
      r.section_type in @section_types and
        matches_parent?(r, struct_row)
    end)
  end

  defp matches_parent?(child, %{section_type: "part"} = parent) do
    child.part == parent.part and child.schedule == parent.schedule
  end

  defp matches_parent?(child, %{section_type: "chapter"} = parent) do
    child.part == parent.part and child.chapter == parent.chapter and
      child.schedule == parent.schedule
  end

  defp matches_parent?(child, %{section_type: "schedule"} = parent) do
    child.schedule == parent.schedule
  end

  defp matches_parent?(_child, _parent), do: false

  # Estimate what fraction of structural text appears in child text.
  # Samples 20-word phrases from structural text and checks child text.
  defp text_overlap_ratio(nil, _child_text), do: 0.0
  defp text_overlap_ratio("", _child_text), do: 0.0
  defp text_overlap_ratio(_structural_text, ""), do: 0.0

  defp text_overlap_ratio(structural_text, child_text) do
    words = String.split(structural_text)
    total_words = length(words)

    if total_words < 10 do
      0.0
    else
      # Sample 20-word windows at regular intervals
      window_size = 20
      step = max(div(total_words, 10), 1)

      samples =
        0..total_words
        |> Enum.take_every(step)
        |> Enum.filter(&(&1 + window_size <= total_words))
        |> Enum.map(fn i ->
          phrase = words |> Enum.slice(i, window_size) |> Enum.join(" ")
          if String.contains?(child_text, phrase), do: 1, else: 0
        end)

      if samples == [] do
        0.0
      else
        Enum.sum(samples) / length(samples)
      end
    end
  end
end
