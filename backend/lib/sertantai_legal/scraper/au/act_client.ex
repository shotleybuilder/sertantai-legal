defmodule SertantaiLegal.Scraper.Au.ActClient do
  @moduledoc """
  Client for ACT legislation register (legislation.act.gov.au).

  Unlike NSW (403 blocked) and QLD (JS-rendered), the ACT site returns
  full HTML that we can parse for metadata.

  URL patterns:
  - Acts: /a/{year}-{number}
  - Subordinate legislation: /sl/{year}-{number}
  - Disallowable instruments: /di/{year}-{number}
  - Notifiable instruments: /ni/{year}-{number}
  """

  require Logger

  @base_url "https://www.legislation.act.gov.au"

  @doc """
  Fetch metadata for an ACT law by its type prefix, year, and number.

  Returns {:ok, metadata} or {:error, reason}.
  """
  @spec fetch_metadata(String.t(), integer(), String.t()) :: {:ok, map()} | {:error, any()}
  def fetch_metadata(type_prefix, year, number) do
    url = "#{@base_url}/#{type_prefix}/#{year}-#{number}"
    fetch_url(url)
  end

  @doc """
  Fetch metadata from a full ACT legislation URL.
  """
  @spec fetch_url(String.t()) :: {:ok, map()} | {:error, any()}
  def fetch_url(url) do
    case Req.get(url, receive_timeout: 15_000, retry: false, redirect: true) do
      {:ok, %Req.Response{status: 200, body: body}} when is_binary(body) ->
        {:ok, parse_page(body, url)}

      {:ok, %Req.Response{status: 404}} ->
        {:ok, nil}

      {:ok, %Req.Response{status: status}} ->
        {:error, {:http_error, status}}

      {:error, reason} ->
        Logger.error("[ACT Client] Request failed: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp parse_page(html, url) do
    status =
      cond do
        html =~ ~r/class="[^"]*repealed[^"]*"/i or html =~ ~r/>Repealed</ ->
          "✗ Repealed"

        html =~ ~r/class="[^"]*in-force[^"]*"/i or html =~ ~r/>Current</ or
            html =~ ~r/>In force</ ->
          "✔ In force"

        true ->
          nil
      end

    repeal_date =
      case Regex.run(~r/Repealed.*?(\d{1,2}\s+\w+\s+\d{4})/s, html) do
        [_, date_str] -> parse_date(date_str)
        _ -> nil
      end

    commenced_date =
      case Regex.run(~r/Commenced.*?(\d{1,2}\s+\w+\s+\d{4})/s, html) do
        [_, date_str] -> parse_date(date_str)
        _ -> nil
      end

    %{
      source_url: url,
      status: status,
      repeal_date: repeal_date,
      commenced_date: commenced_date
    }
  end

  defp parse_date(date_str) do
    # Parse "1 July 2021" or "14 December 2010" format
    months = %{
      "january" => 1,
      "february" => 2,
      "march" => 3,
      "april" => 4,
      "may" => 5,
      "june" => 6,
      "july" => 7,
      "august" => 8,
      "september" => 9,
      "october" => 10,
      "november" => 11,
      "december" => 12
    }

    case Regex.run(~r/(\d{1,2})\s+(\w+)\s+(\d{4})/, date_str) do
      [_, day, month_name, year] ->
        month = Map.get(months, String.downcase(month_name))

        if month do
          case Date.new(String.to_integer(year), month, String.to_integer(day)) do
            {:ok, date} -> date
            _ -> nil
          end
        end

      _ ->
        nil
    end
  end
end
