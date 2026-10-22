defmodule SertantaiLegal.Scraper.ChangeVocabulary.StoreTest do
  @moduledoc """
  The change register's value codec (CV-04): every claim value type the
  readers write reads back as written.
  """
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeVocabulary.Store

  test "values round-trip through the tagged JSON" do
    for v <- [
          nil,
          true,
          false,
          :repealed_in_part,
          "E+W",
          42,
          ~D[2024-03-25],
          ["s.1", "s.2"],
          [~D[2020-01-01], :words],
          {:date, ~D[2021-12-09]},
          %{date: ~D[2020-03-25], territory: "W"},
          [%{"by" => "UK_uksi_2021_1399", at: [~D[2022-01-01]]}]
        ] do
      encoded = Store.encode(v)
      assert is_map(encoded)
      # stored as JSON: what comes back is what Jason decodes
      assert encoded |> Jason.encode!() |> Jason.decode!() |> Store.decode() == v
    end
  end

  test "a struct is refused (no silent loss)" do
    assert_raise ArgumentError, fn -> Store.encode(URI.parse("http://x")) end
  end
end
