# Baumeister

Baumeister is a build management system, inspired by Jenkins, Travis CI and BuildBot.

## Design

* Central service is the Baumeister Service, which manages the overall process
* Observers are dynamic GenServer, which observe a source code repository for
  changes. The function for observing is injected from a plugin-like structure
  to support different repositories and the like. It returns the BaumeisterFile.
  The BaumeisterFile is analyzed by the Baumeister, searching for a
  matching BuildNode.
* The BuildNode gets a URL to the repository, checks out the repository and
  applies the BaumeisterFile.
* Events, e.g. build checkout, build started, build sucess, ..., are sent from
  the BuildNode and the Observers to the central servers. Visualizers and
  reporting tools can subscribe to the central servers to get access of the
  events.
* Similarly, the build results (i.e. log files, ...) will be made available.
* Standard reporting and user interface is a Baumeister Web application based on
  Phoenix. 
##
