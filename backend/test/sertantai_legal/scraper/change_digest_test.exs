defmodule SertantaiLegal.Scraper.ChangeDigestTest do
  use ExUnit.Case, async: true

  alias SertantaiLegal.Scraper.ChangeDigest
  alias SertantaiLegal.Scraper.ChangeVocabulary.{Change, Claim, Evidence}

  defp change(key, target, claims) do
    %Change{
      key: key,
      target: target,
      claims: for({s, a, v} <- claims, do: %Claim{source: s, attribute: a, value: v, ref: key})
    }
    |> Evidence.resolve("E+W")
  end

  defp a,
    do: change("key-a", "s.78", [{:feed, :operation, :repealed}, {:feed, :date, ~D[2024-03-25]}])

  defp b, do: change("key-b", "s.79", [{:markup, :operation, :inserted}])

  test "the same changes give the same digest, whatever their order" do
    assert ChangeDigest.of([a(), b()]) == ChangeDigest.of([b(), a()])
    assert ChangeDigest.of([a(), b()]) =~ ~r/^[0-9a-f]{16}$/
  end

  test "a changed value, claim or target changes the digest" do
    d = ChangeDigest.of([a(), b()])

    other_date =
      change("key-a", "s.78", [{:feed, :operation, :repealed}, {:feed, :date, ~D[2024-03-26]}])

    assert ChangeDigest.of([other_date, b()]) != d
    assert ChangeDigest.of([%{a() | target: "s.78(1)"}, b()]) != d
    assert ChangeDigest.of([a()]) != d
  end

  test "a claim's position counts (claims are stored in order)" do
    swapped = %{a() | claims: Enum.reverse(a().claims)}
    assert ChangeDigest.of([swapped, b()]) != ChangeDigest.of([a(), b()])
  end

  test "no changes" do
    assert ChangeDigest.of([]) == ChangeDigest.of([])
  end
end
