# Baumeister Core

This application is the functional core of Baumeister. It contains the
basic implementations of  

* the `Baumeister.Observer`, which keeps an eye on changes
in repositories,
* the `Baumeister.Worker`, realizing the distributed
build engine
* the `Baumeister.Coordinator`, assigning build jobs to workers to make a good
match of job requirements and worker capabilities.
* the `Baumeister.BaumeisterFile`, defining the language of Baumeister to
define a build job.
* the `Baumeister.Observer.Coordinate`, defining a coordinate to version in a
repository, where Observer-Plugins can extend the version specification for
their need.
* the `Baumeister.EventCenter`, collecting build events from the workers and
  transferring them to any subscribed listeners. This is an important API piece
  for connecting Web frontends and the like to the Baumeister Core.
* the `Baumeister.EventLogger`, a simple event listener and helpful device
  for debugging the Event Center.
* the `Baumeister.Config` holding information about configured projects including
  plugins, buildnumbers and the like. The name is somewhat misleading. It is
  also an important API to connect a Web frontend to the Baumeister Core.


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `baumeister` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:baumeister, "~> 0.1.0"}]
    end
    ```

  2. Ensure `baumeister` is started before your application:

    ```elixir
    def application do
      [applications: [:baumeister]]
    end
    ```
