defmodule SertantaiLegal.Scraper.LawStart.MadeCondition do
  @moduledoc """
  A commencement clause's head conditional on the day the law is made: "If
  this Order is made on or before 30th December 2024—" over one list, "If
  this Order is made on or after 31st December 2024—" over another (SI
  2024/1366 art.2(2), (3)). The making day decides which head's statements
  the law states; the other head's state nothing. Pure.
  """

  alias SertantaiLegal.Scraper.LawStart.{Clause, OwnDays}

  @head ~r/^\W*(?:\(\w+\)\s*)?If\s+(?:this|these)\s+(?:Order|Regulations|Rules|Scheme|Instrument)\s+(?:is|are)\s+made\s+(on\s+or\s+before|on\s+or\s+after|before|after|on)\s+(?:the\s+)?(\d.+?)\s*[—–:,-]?\s*$/is

  @doc """
  Whether the condition `text` states holds for a law made on `made`: nil
  when `text` is no such head, its day is unread, or `made` is not held.
  """
  @spec holds?(String.t() | nil, OwnDays.days()) :: boolean() | nil
  def holds?(text, %Date{} = made) when is_binary(text) do
    with [_, relation, day] <- Regex.run(@head, text),
         %Date{} = d <- Clause.date_at_start(day) do
      compare(
        relation |> String.downcase() |> String.replace(~r/\s+/, " "),
        Date.compare(made, d)
      )
    else
      _ -> nil
    end
  end

  def holds?(text, %OwnDays{made: made}), do: holds?(text, made)
  def holds?(_text, _made), do: nil

  defp compare("on or before", order), do: order in [:lt, :eq]
  defp compare("on or after", order), do: order in [:gt, :eq]
  defp compare("before", order), do: order == :lt
  defp compare("after", order), do: order == :gt
  defp compare("on", order), do: order == :eq

  @doc "`rows` less every head whose condition fails for `made`, and the rows under it."
  @spec holding([map()], OwnDays.days()) :: [map()]
  def holding(rows, made) do
    case failing(rows, made) do
      [] -> rows
      failing -> Enum.reject(rows, &(&1.section_id in failing))
    end
  end

  @doc "The ids of the heads whose condition fails for `made`, and of the rows under them."
  @spec failing([map()], OwnDays.days()) :: [String.t()]
  def failing(_rows, nil), do: []

  def failing(rows, made) do
    heads = for r <- rows, holds?(Map.get(r, :text), made) == false, do: r.section_id

    for %{section_id: id} <- rows,
        Enum.any?(heads, &(id == &1 or String.starts_with?(id, &1 <> "("))),
        do: id
  end
end
