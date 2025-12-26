defmodule SertantaiLegal.Legal.Taxa.DutyTypeDefnGovernment do
  @moduledoc """
  Regex pattern definitions for classifying responsibilities and powers of government entities.

  Government entities include authorities, agencies, ministers, and other official bodies.
  This module provides patterns to identify:

  - **Responsibilities**: Duties/obligations placed on government
  - **Powers Conferred**: Discretionary powers granted to government

  ## Responsibility Patterns

  Common patterns include:
  - "The authority must..."
  - "The Minister shall..."
  - "It shall be the duty of the Secretary of State..."

  ## Power Patterns

  Common patterns include:
  - "The Minister may by regulations..."
  - "The authority may direct..."
  - "The Secretary of State shall have the power..."

  ## Usage

      iex> DutyTypeDefnGovernment.responsibility("[Aa]uthority")
      ["authority(?:must|shall)...", ...]

      iex> DutyTypeDefnGovernment.power_conferred("[Mm]inister")
      ["Minister.*?may.*?by regulations...", ...]
  """

  @type pattern :: String.t()

  # Em dash character
  @emdash <<226, 128, 148>>

  @doc """
  Returns regex patterns for identifying responsibilities placed on government entities.

  ## Parameters

  - `government`: A regex pattern for the government entity (e.g., "[Aa]uthority")
  """
  @spec responsibility(String.t()) :: list(pattern())
  def responsibility(government) do
    [
      "#{government}(?:must|shall)(?! have the power)",
      "#{government}[^—\\.]*?(?:must|shall)(?! have the power)",
      # a ... within the middle of the sentence
      "#{government}[^—\\.]*?[\\.\\.\\.].*?(?:must|shall)",
      "must be (?:carried out|reviewed|sent|prepared|specified by).*?#{government}",
      "#{government}[^—\\.]*?has determined",
      "[Ii]t shall be the duty of a?n?[^—\\.]*?#{government}",
      "#{government} owes a duty to",
      "is to be.*?by a#{government}",
      "#{government}is to (?:perform|have regard)",
      "#{government}may not",
      "#{government}is (?:liable|responsible for)",
      "[Ii]t is the duty of the#{government}",
      # Pattern when there are dutyholder options and MODALS start on a new line
      # s modifier: single line. Dot matches newline characters
      "#{government}.*?#{@emdash}(?s:.)*?^.*?(?:must|shall)"
    ]
  end

  @doc """
  Returns regex patterns for identifying powers conferred on government entities.

  ## Parameters

  - `government`: A regex pattern for the government entity (e.g., "[Mm]inister")
  """
  @spec power_conferred(String.t()) :: list(pattern())
  def power_conferred(government) do
    [
      "#{government}.*?may.*?by regulations?.*?(?:specify|substitute|prescribe|make)",
      "#{government} may.*?direct ",
      "#{government} may vary the terms",
      "#{government} may.*make.*(scheme|plans?|regulations?) ",
      "#{government} considers necessary",
      "#{government}.*?shall (?:have the power|be entitled)",
      "#{government} may by regulations?",
      "#{government}[^—\\.]*?may(?![ ]not|[ ]be)",
      # a ... within the middle of the sentence
      "#{government}[^—\\.]*?[\\.\\.\\.].*?may(?![ ]not)",
      "#{government}is not required",
      "may be (?:varied|terminated) by the#{government}",
      "may be excluded.*?by directions of the #{government}",
      " in the opinion of the #{government} ",
      # Pattern when there are dutyholder options and MODALS start on a new line
      # s modifier: single line. Dot matches newline characters
      "#{government}.*?#{@emdash}(?s:.)*?^.*?may(?![ ]not|[ ]be)"
    ]
  end
end
