defmodule ConfigTest do
  use ExUnit.Case
  doctest Baumeister.Config
  alias Baumeister.Config

  use PropCheck

  test "add and clean" do
    Config.start_link()
    Config.remove_all()
    assert Config.keys == []

    Config.put(:x, 5)
    assert {:ok, 5} == Config.config(:x)

    Config.put(:x, 7)
    assert {:ok, 7} == Config.config(:x)

    Config.remove_all()
    assert Config.keys == []

    Config.put(:"", "")
    assert :error == Config.config(:x)
    assert {:ok, ""} == Config.config(:"")
  end

  property "source holds all keys" do
    Config.start_link()
    forall values <- [{atom(), utf8()}] do
        Config.remove_all()
        m =  Enum.into(values, %{})
        Enum.each(values, fn({k, v}) -> Config.put(k, v) end)
        keys = Config.keys
        keys == Map.keys(m)
    end
  end

  property "source holds all values of existing keys" do
    Config.start_link()
    forall values <- [{atom(), utf8()}] do
        Config.remove_all()
        m = Enum.into(values, %{})
        Enum.each(values, fn({k, v}) -> Config.put(k, v) end)

        source_values = Enum.map(Config.keys,
          fn(k) -> {:ok, v} = Config.config(k)
            v end)
        m_values = m
        |> Map.keys()
        |> Enum.map(&(Map.fetch!(m, &1)))

        source_values == m_values
    end
  end

end
