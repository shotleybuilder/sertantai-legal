defmodule SertantaiLegal.Legal.SecondarySource.ParserProfile do
  @moduledoc """
  Profile for PDF provision parsing — encapsulates publisher-specific
  font thresholds, numbering patterns, and skip rules.

  Auto-detected from document content or explicitly selected via
  `--profile` on the mix task / `structure_type` on SecondarySource.

  ## Adding a new profile

  1. Create a module implementing `classify_line/2` and `numbered_paragraph?/1`
  2. Add a detection clause to `detect/2`
  3. Test on 2-3 documents from that publisher
  """

  @type font_profile :: %{
          body_size: float(),
          title_min: float(),
          section_min: float(),
          sub_heading_min: float(),
          footnote_max: float()
        }

  @type t :: %__MODULE__{
          name: atom(),
          publisher: String.t(),
          fonts: font_profile()
        }

  defstruct [:name, :publisher, :fonts]

  @doc """
  Detect the appropriate parser profile from raw extracted lines.
  Examines font size distribution and first-page text for publisher signals.
  """
  def detect(lines, source \\ nil) do
    body_size = detect_body_size(lines)
    publisher = detect_publisher(lines)

    profile_name =
      cond do
        # Explicit hint from source record
        source && source.source_type == :acop -> :hse_acop
        source && source.source_type == :guidance -> :hse_guidance
        # Publisher detection from document text
        publisher == :hse -> :hse_acop
        publisher == :mod -> :mod_jsp
        # Fallback based on body font size
        body_size <= 10.5 -> :hse_acop
        true -> :mod_jsp
      end

    build(profile_name, body_size)
  end

  @doc """
  Build a profile by name with the detected body font size.
  """
  def build(name, body_size) do
    case name do
      :mod_jsp -> mod_jsp(body_size)
      :hse_acop -> hse_acop(body_size)
      :hse_guidance -> hse_acop(body_size)
      _ -> mod_jsp(body_size)
    end
  end

  # ---------------------------------------------------------------------------
  # Profile definitions
  # ---------------------------------------------------------------------------

  defp mod_jsp(body_size) do
    %__MODULE__{
      name: :mod_jsp,
      publisher: "MoD",
      fonts: %{
        body_size: body_size,
        title_min: body_size * 1.6,
        section_min: body_size + 2.0,
        sub_heading_min: body_size,
        footnote_max: body_size * 0.7
      }
    }
  end

  defp hse_acop(body_size) do
    %__MODULE__{
      name: :hse_acop,
      publisher: "HSE",
      fonts: %{
        body_size: body_size,
        title_min: body_size * 2.5,
        section_min: body_size + 4.0,
        sub_heading_min: body_size,
        footnote_max: body_size * 0.75
      }
    }
  end

  # ---------------------------------------------------------------------------
  # Detection helpers
  # ---------------------------------------------------------------------------

  defp detect_body_size(lines) do
    lines
    |> Enum.filter(&(&1.bold == false and &1.font_size != nil))
    |> Enum.frequencies_by(& &1.font_size)
    |> Enum.max_by(fn {_size, count} -> count end, fn -> {12.0, 0} end)
    |> elem(0)
  end

  defp detect_publisher(lines) do
    # Check first 3 pages of text for publisher signals
    first_page_text =
      lines
      |> Enum.filter(&(&1.page <= 3))
      |> Enum.map_join(" ", & &1.text)
      |> String.downcase()

    cond do
      String.contains?(first_page_text, "health and safety executive") -> :hse
      String.contains?(first_page_text, "hse books") -> :hse
      String.contains?(first_page_text, "ministry of defence") -> :mod
      String.contains?(first_page_text, "jsp ") -> :mod
      String.contains?(first_page_text, "defence safety") -> :mod
      true -> :unknown
    end
  end
end
