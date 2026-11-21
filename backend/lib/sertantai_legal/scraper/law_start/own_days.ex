defmodule SertantaiLegal.Scraper.LawStart.OwnDays do
  @moduledoc """
  The days a law's own commencement words count from: the day it is made
  (an Act's passing) and the day it is laid ("on the 22nd day after the day
  on which these Regulations are laid": SI 2018/1221 reg.2(a)). Carried
  where the made day alone was, so a reader given only a made day (a date,
  or none) reads as before, with no laid day held. Pure.
  """

  defstruct [:made, :laid]

  @type t :: %__MODULE__{made: Date.t() | nil, laid: Date.t() | nil}

  @typedoc "The days, or the made day alone (as callers gave it before the laid day was carried)."
  @type days :: t() | Date.t() | nil

  @doc "The days a reader's input (`LawStart.input/0`) holds."
  @spec of(map()) :: t()
  def of(input), do: %__MODULE__{made: Map.get(input, :made), laid: Map.get(input, :laid)}

  @doc "The made day (an Act's passing); nil when not held."
  @spec made(days()) :: Date.t() | nil
  def made(%__MODULE__{made: made}), do: made
  def made(%Date{} = made), do: made
  def made(nil), do: nil

  @doc "The laid day; nil when not held."
  @spec laid(days()) :: Date.t() | nil
  def laid(%__MODULE__{laid: laid}), do: laid
  def laid(_made), do: nil
end
