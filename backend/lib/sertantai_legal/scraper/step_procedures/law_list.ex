defmodule SertantaiLegal.Scraper.StepProcedures.LawList do
  @moduledoc """
  A list of law names as a task takes it: `A,B` on the command line, or
  `@FILE`, one law a line (commas also split). Blanks and repeats go, and
  the last line counts with or without a final newline (a list file with
  none once dropped the last 2 laws of an extent write: Fire and OH&S).
  """

  @doc "The laws `arg` names: a comma list, or `@path` to a file of them."
  @spec parse(String.t()) :: [String.t()]
  def parse("@" <> path), do: path |> File.read!() |> split()
  def parse(list), do: split(list)

  @doc "The law names in `text`, split on commas and whitespace, in order, each once."
  @spec split(String.t()) :: [String.t()]
  def split(text), do: text |> String.split(~r/[\s,]+/u, trim: true) |> Enum.uniq()
end
