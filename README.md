# Baumeister

Baumeister is a build management system, inspired by Jenkins, Travis CI and BuildBot.

[![Build Status](https://travis-ci.org/alfert/baumeister.svg?branch=master)](https://travis-ci.org/alfert/baumeister)
[![Ebert](https://ebertapp.io/github/alfert/baumeister.svg)](https://ebertapp.io/github/alfert/baumeister)

Currently, Baumeister is in statu nascendi and merely useful. While moving
from release 0.1.0 towards 1.0.0 this will change...

## Binary Releases and Configuration

Baumeister uses `distillery`(https://hexdocs.pm/distillery/getting-started.html)
to create binary releases with `mix release baumeister` and `mix release bm_worker`.
In order to set the Erlang node names properly, these names are not baked into
the release, but are required to inject via environment variables:

* NODE_NAME: name of the node to be started/stopped etc.
* REPLACE_OS_VARS=1: use the above node name
* COORDINATOR: name of the coordinator node, to which workers connect

An example from within the build environment of starting a coordinator and a
worker node:

    $ REPLACE_OS_VARS=1 NODE_NAME=baumeister _build/dev/rel/baumeister/bin/baumeister console
    $ REPLACE_OS_VARS=1 COORDINATOR=baumeister@localhost NODE_NAME=bm_worker1 _build/dev/rel/bm_worker/bin/bm_worker console

Only full node names are supported, short names do not work! If the node names
does not contain an `@` sign, the current hostname is automatically added.

This approach enables to start many workers on the same machine and from the
same installed binary package.

## Design

* Central service is the Baumeister Service, which manages the overall process
* Observers are dynamic GenServer, which observe a source code repository for
  changes. The function for observing is injected from a plugin-like structure
  to support different repositories and the like. It returns the BaumeisterFile.
  The BaumeisterFile is analyzed by the Baumeister, searching for a
  matching build worker.
* The worker gets a URL to the repository, checks out the repository and
  applies the BaumeisterFile.
* Events, e.g. build checkout, build started, build success, ..., are sent from
  the workers and the observers to an event center. Visualizers and
  reporting tools can subscribe to the event center to receive the
  events.
* Similarly, the build results (i.e. log files, ...) will be made available.
* Standard reporting and user interface is a Baumeister Web application based on
  Phoenix.

## Data Handling

* Project definitions are stored in a Mnesia database.
* Build log files are stored as JSON text files (with optional compressing) in
  flat file storage, because they become very large very easily.
* Build results, i.e. metadata with time/date, project, version coordinate,
  build number (= sequential ordering), state (`:unknown`, `running`, `success`,
  `failed`) and URL for the entre log file are stored in a Mnesia database
  and as part of the log files. 
* The log files can be compressed as a service scheme, e.g. as aggregated results
  as in a RDD database or only leaving official builds, such as PRs, releases
  or something similar.

## Contributing

Please use the GitHub issue tracker for

* bug reports and for
* submitting pull requests

## License

Baumeister is provided under the Apache 2.0 License.
