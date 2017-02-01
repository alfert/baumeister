# Baumeister Coordinator

This project contains the code specific to the Baumeister Coordinator
server. It uses nearly all of `baumeister_core` for dealing with repositories,
plugins and the like. In the initial version, it is only small layer
around `baumeister_core` to ease startup and release management with `distillery`.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `coordinator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [{:baumeister_coordinator, "~> 0.1.0"}]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/coordinator](https://hexdocs.pm/coordinator).
