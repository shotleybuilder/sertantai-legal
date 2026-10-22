defmodule SertantaiLegal.Scraper.ChangeVocabulary.Store.Codec do
  @moduledoc """
  A claim value as type-tagged JSON (CV-04), so it reads back as written:
  `{"t": tag, "v": value}` for nil, booleans, atoms, strings, integers,
  floats, dates, lists, tuples and maps (keys encoded too). Any other
  struct is refused — never stored as something else. Pure.
  """

  @doc "The tagged JSON map for `value`."
  @spec encode(term()) :: map()
  def encode(nil), do: %{"t" => "nil"}
  def encode(v) when is_boolean(v), do: %{"t" => "bool", "v" => v}
  def encode(v) when is_atom(v), do: %{"t" => "atom", "v" => Atom.to_string(v)}
  def encode(v) when is_binary(v), do: %{"t" => "str", "v" => v}
  def encode(v) when is_integer(v), do: %{"t" => "int", "v" => v}
  def encode(v) when is_float(v), do: %{"t" => "float", "v" => v}
  def encode(%Date{} = d), do: %{"t" => "date", "v" => Date.to_iso8601(d)}
  def encode(v) when is_list(v), do: %{"t" => "list", "v" => Enum.map(v, &encode/1)}

  def encode(v) when is_tuple(v),
    do: %{"t" => "tuple", "v" => v |> Tuple.to_list() |> Enum.map(&encode/1)}

  def encode(%_{} = s),
    do: raise(ArgumentError, "a #{inspect(s.__struct__)} is not a claim value")

  def encode(v) when is_map(v),
    do: %{
      "t" => "map",
      "v" => v |> Enum.sort() |> Enum.map(fn {k, x} -> [encode(k), encode(x)] end)
    }

  @doc "The value a tagged JSON map stands for."
  @spec decode(map()) :: term()
  def decode(%{"t" => "nil"}), do: nil
  def decode(%{"t" => "bool", "v" => v}), do: v
  # our own atoms, written by `encode/1` (a reader's may not be loaded yet)
  def decode(%{"t" => "atom", "v" => v}), do: String.to_atom(v)
  def decode(%{"t" => "str", "v" => v}), do: v
  def decode(%{"t" => "int", "v" => v}), do: v
  def decode(%{"t" => "float", "v" => v}), do: v
  def decode(%{"t" => "date", "v" => v}), do: Date.from_iso8601!(v)
  def decode(%{"t" => "list", "v" => v}), do: Enum.map(v, &decode/1)
  def decode(%{"t" => "tuple", "v" => v}), do: v |> Enum.map(&decode/1) |> List.to_tuple()
  def decode(%{"t" => "map", "v" => v}), do: Map.new(v, fn [k, x] -> {decode(k), decode(x)} end)
end
