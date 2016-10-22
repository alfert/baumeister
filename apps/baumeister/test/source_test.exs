defmodule SourceTest do
  use ExUnit.Case
  doctest Baumeister.Source
  alias Baumeister.Source

  use PropCheck

  test "add and clean" do
    Source.start_link()
    Source.remove_all()
    assert Source.keys == []

    Source.put(:x, 5)
    assert {:ok, 5} == Source.config(:x)

    Source.put(:x, 7)
    assert {:ok, 7} == Source.config(:x)

    Source.remove_all()
    assert Source.keys == []

    Source.put(:"", "")
    assert :error == Source.config(:x)
    assert {:ok, ""} == Source.config(:"")
  end

  property "source holds all keys" do
    Source.start_link()
    forall values <- [{atom, utf8}] do
        Source.remove_all()
        m = values |> Enum.into(%{})
        values |> Enum.each(fn({k, v}) -> Source.put(k, v) end)
        keys = Source.keys
        keys == Map.keys(m)
    end
  end

  property "source holds all values of existing keys" do
    Source.start_link()
    forall values <- [{atom, utf8}] do
        Source.remove_all()
        m = values |> Enum.into(%{})
        values |> Enum.each(fn({k, v}) -> Source.put(k, v) end)

        source_values = Source.keys
        |> Enum.map(fn(k) -> {:ok, v} = Source.config(k)
            v end)
        m_values = m |> Map.keys() |> Enum.map(&(Map.fetch!(m, &1)))

        source_values == m_values
    end
  end

end
