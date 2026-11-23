defmodule SertantaiLegal.Scraper.Amendment.ProvisionRead do
  @moduledoc """
  Gives the rules one amending provision states (`Amendment.Reader.read/4`),
  with the amending law's defined terms memoised in the calling process.

  The new path's build (`Amendment.ReadLaw`) and the read pass call this
  module. It is not the old collector (`Amendment.Collect`), which
  delegates to it, so the build's stamp holds neither the collector nor
  the old dater (Commencement reader decouple, 2026-11-23;
  `OldPathFenceTest`).
  """

  alias SertantaiLegal.Scraper.AmendingLaw.{DefinedTerms, Doc}
  alias SertantaiLegal.Scraper.Amendment.{Reader, Rule}

  @doc "The rules the amending provision `id` in `doc` states for `laws`."
  @spec read(Doc.t(), String.t(), [Reader.law_ref()]) :: [Rule.t()]
  def read(doc, id, laws), do: Reader.read(doc, id, terms(doc), laws)

  defp terms(doc) do
    key = {__MODULE__, :terms, doc.law_name}

    case Process.get(key, :none) do
      :none -> tap(DefinedTerms.of(doc), &Process.put(key, &1))
      terms -> terms
    end
  end

  @doc "Drop the memoised defined terms from the calling process."
  @spec clear() :: :ok
  def clear do
    for {__MODULE__, _, _} = k <- Process.get_keys(), do: Process.delete(k)
    :ok
  end
end
