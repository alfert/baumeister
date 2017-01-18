# Baumeister

Baumeister is a build management system, inspired by Jenkins, Travis CI and BuildBot.

[![Build Status](https://travis-ci.org/alfert/baumeister.svg?branch=master)](https://travis-ci.org/alfert/baumeister)

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

## Contributing

Please use the GitHub issue tracker for

* bug reports and for
* submitting pull requests

## License

Baumeister is provided under the Apache 2.0 License.
