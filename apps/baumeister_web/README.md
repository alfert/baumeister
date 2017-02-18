# BaumeisterWeb

## Design

`BaumeisterWeb` uses the BaumeisterCoordinator and BaumeisterCore for all
serious backend tasks. On the web frontend, a project is defined and updated,
finally stored in a Mnesia database. At the same time, for each defined project
a Baumeister configuration is added. An observer is started, after the
project configuration is enabled from the web. The major task of BaumeisterWeb
is to manage this connection, essentially translating the entries from a
userfriendly form to the details required by the Baumeister backend.

The second task is to listen to all the events that appear in the context
of an project, streaming the results from the observer and the workers to the user
interface and recognice each build together with pointers where the log output is
currently stored. This offline log output is required if the user comes back to
former builds or to a build which he was not observing online.

## Trivia

To start your Phoenix app:

  * Install dependencies with `mix deps.get`
  * Create and migrate your database with `mix ecto.create && mix ecto.migrate`
  * Install Node.js dependencies with `npm install`
  * Start Phoenix endpoint with `mix phoenix.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](http://www.phoenixframework.org/docs/deployment).

## Learn more

  * Official website: http://www.phoenixframework.org/
  * Guides: http://phoenixframework.org/docs/overview
  * Docs: https://hexdocs.pm/phoenix
  * Mailing list: http://groups.google.com/group/phoenix-talk
  * Source: https://github.com/phoenixframework/phoenix
