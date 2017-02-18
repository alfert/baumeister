alias Experimental.GenStage

defmodule Baumeister.EventCenter do
  @moduledoc """
  This module implements the services required for sending, receiving
  and dispatching events. It is implemented via the (experimental) `GenStage`
  module.

  We model out process after `QueueBroadcaster` to allow for
  various different consumers which might fail and come and go.

  """

  use GenStage
  require Logger

  @typedoc """
  Holds the internal state of the `EventCenter`.

  * `queue`: the queue of events
  * `demand`: the current demand of events to consume
  """
  @type t :: %__MODULE__{
    queue: :queue.queue,
    demand: non_neg_integer
  }
  defstruct queue: :queue.new, demand: 0

###################################################
##
## EventCenter API
##
###################################################

@doc "Name of the EventCenter process"
def name, do: {:global, __MODULE__}

def is_running() do
  nil != GenServer.whereis(name())
end

 @doc "Starts the EventCenter registered with the module's name."
 @spec start_link() :: {:ok, pid}
 def start_link() do
   Logger.info "Start the EventCenter server"
   GenStage.start_link(__MODULE__, :ok, name: name())
 end
 @doc """
 Starts the EventCenter as an anonymous process which is not registered.
 This is used for testing purposes. The parameter `:anon` must be provided.
 """
 @spec start_link(:anon) :: {:ok, pid}
 def start_link(:anon) do
   GenStage.start_link(__MODULE__, :ok, [])
 end

 @doc "Sends an event and returns only after the event is dispatched."
 @spec sync_notify(any, pos_integer | :infinity) :: :ok
 @spec sync_notify(pid | atom | {atom, any}, any, pos_integer | :infinity) :: :ok
 def sync_notify(pid \\ name(), event, timeout \\ 5000) do
   Logger.debug("Sent sync_notify to Stage #{inspect pid} with event: #{inspect event}")
   GenStage.call(pid, {:notify, event}, timeout)
 end

 @doc """
 Empties the queue of events.
 """
 def clear(pid \\ name()) do
   GenStage.call(pid, :clear)
 end

 @doc "Stops the EventCenter"
 def stop(pid \\ name()) do
   GenStage.stop(pid)
 end

 ###################################################
 ##
 ## Callback Implementation
 ##
 ###################################################

 @doc false
 def init(:ok) do
   {:producer, %__MODULE__{}, dispatcher: GenStage.BroadcastDispatcher}
 end

 @doc false
 def handle_call({:notify, event}, from, state = %__MODULE__{queue: queue}) do
   added_queue = :queue.in({from, event}, queue)
   dispatch_events(%__MODULE__{state | queue: added_queue}, [])
 end
 def handle_call(:clear, _from, state = %__MODULE__{queue: queue, demand: demand}) do
   {:reply, :queue.len(queue), [], %__MODULE__{state | queue: :queue.new(), demand: demand}}
 end
 @doc false
 def handle_demand(incoming_demand, state = %__MODULE__{demand: pending_demand}) do
   new_demand = incoming_demand + pending_demand
   dispatch_events(%__MODULE__{state | demand: new_demand}, [])
 end

 defp dispatch_events(state = %__MODULE__{demand: 0}, events) do
   {:noreply, Enum.reverse(events), state}
 end
 defp dispatch_events(state = %__MODULE__{queue: queue, demand: demand}, events) do
   case :queue.out(queue) do
     {{:value, {from, event}}, new_queue} ->
       GenStage.reply(from, :ok)
       dispatch_events(%__MODULE__{queue: new_queue, demand: demand - 1}, [event | events])
     {:empty, _queue} ->
       {:noreply, Enum.reverse(events), state}
   end
 end

end
