defmodule Baumeister.Worker do
  @moduledoc """
  A Baumeister node is the working horse of Baumeister. Usually running on its
  own Erlang VM, a node is connected with a Baumeister server and waits for
  jobs to done.
  """

  alias Baumeister.Coordinator

  defstruct [:coordinator]

  use GenServer

  def start_link() do
    coordinator = Application.get_env(:baumeister, :coordinator, Coordinator.name())
    GenServer.start_link(__MODULE__, [coordinator])
  end


  def init([coordinator]) do
    state = %__MODULE__{coordinator: coordinator}
    {:ok, state}
  end

end
