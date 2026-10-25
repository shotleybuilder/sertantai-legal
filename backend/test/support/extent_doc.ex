defmodule SertantaiLegal.ExtentDoc do
  @moduledoc """
  Builders for the extent reader's tests (`AmendingLaw.Extent` and its
  modules): a law's document from P1 provisions.
  """

  alias SertantaiLegal.Scraper.AmendingLaw.Doc

  @doc "A law's document from its body XML."
  @spec doc(String.t(), String.t()) :: Doc.t()
  def doc(law, body),
    do: Doc.new(law, ["<Legislation><Primary><Body>#{body}</Body></Primary></Legislation>"])

  @doc "A P1 provision holding one text."
  @spec p1(String.t(), String.t()) :: String.t()
  def p1(id, text), do: ~s(<P1 id="#{id}"><P1para><Text>#{text}</Text></P1para></P1>)
end
