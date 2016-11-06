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

 @doc "Starts the EventCenter."
 @spec start_link() :: {:ok, pid}
 def start_link() do
   GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
 end

 @doc "Sends an event and returns only after the event is dispatched."
 @spec sync_notify(any, pos_integer | :infinity) :: :ok
 def sync_notify(event, timeout \\ 5000) do
   GenStage.call(__MODULE__, {:notify, event}, timeout)
 end

 @doc "Stops the EventCenter"
 def stop() do
   GenStage.stop(__MODULE__)
 end

 ###################################################
 ##
 ## Callback Implementation
 ##
 ###################################################

 def init(:ok) do
   {:producer, %__MODULE__{}, dispatcher: GenStage.BroadcastDispatcher}
 end

 def handle_call({:notify, event}, from, state = %__MODULE__{queue: queue}) do
   added_queue = :queue.in({from, event}, queue)
   dispatch_events(%__MODULE__{state | queue: added_queue}, [])
 end
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
