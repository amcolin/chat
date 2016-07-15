defmodule Chat.Channel do
  @moduledoc """
  A process holding a channel's state.
  """

  use GenServer

  defstruct name: "",
            motd: "",
            event_manager: nil, # GenEvent
            users: []           # [{pid, name, monitor}, ...]

  #
  # Client API
  #

  @doc """
  Start a new channel process, and initialize its data to `data`
  (type=%Chat.Channel). This function should be called only by the controller.
  """
  def start_link(data) do
    GenServer.start_link(__MODULE__, data)
  end

  @doc """
  Stop the `channel` process, destroying its data.
  """
  def stop(channel) do
    GenServer.stop(channel, :normal)
  end

  @doc """
  Return the data associated with the `channel`.
  """
  def get(channel) do
    GenServer.call(channel, {:get})
  end

  @doc """
  Return the list of users that have joined the `channel`.
  """
  def users(channel) do
    GenServer.call(channel, {:users})
  end

  @doc """
  Update the `channel` process's `data`.
  """
  def update(channel, data) do
    GenServer.call(channel, {:update, data})
  end

  @doc """
  Update the `channel` message of the day to `motd`.
  """
  def update_motd(channel, motd) do
    GenServer.call(channel, {:update_motd, motd})
  end

  @doc """
  Add the `user` to the `channel`. This starts a process monitor on the user
  process, so the channel's list will be updated if the user process dies.
  Return :already_added if the user was already a member of the channel's
  user list. Otherwise return :ok.
  """
  def add_user(channel, user) do
    GenServer.call(channel, {:add_user, user})
  end

  @doc """
  Remove the `user` from the `channel`'s list of active users. Return
  :not_found if the user was not found on the channel's member list. Otherwise
  return :ok.
  """
  def remove_user(channel, user) do
    GenServer.call(channel, {:remove_user, user})
  end

  @doc """
  Publish a `msg` to all subscribers of the `channel`. Use the [flush: true]
  option to force all pending messages to be flushed after publishing.
  """
  def publish(channel, msg, options \\ []) do
    GenServer.call(channel, {:publish, msg, options})
  end

  @doc """
  Subscribe to a stream of notifications published to the `channel`. Return
  the stream.
  """
  def subscribe(channel) do
    GenServer.call(channel, {:get_event_manager})
    |> GenEvent.stream
  end

  @doc """
  Subscribe to notifications published to the `channel`. Notifications arrive
  at the `handler`'s handle_event(event, `arg`) function.
  """
  def subscribe(channel, handler, arg) do
    GenServer.call(channel, {:get_event_manager})
    |> GenEvent.add_handler(handler, arg)
  end

  @doc """
  Return true if the `user` is a member of the `channel`.
  """
  def member?(channel, user) do
    GenServer.call(channel, {:member?, user})
  end

  #
  # Server callbacks
  #

  def init(data) do
    {:ok, event_manager} = GenEvent.start_link()
    {:ok, put_in(data.event_manager, event_manager)}
  end

  def handle_call({:get}, _from, data) do
    {:reply, data, data}
  end

  def handle_call({:get_event_manager}, _from, data) do
    {:reply, data.event_manager, data}
  end

  def handle_call({:users}, _from, data) do
    {:reply, Enum.map(data.users, fn {u, _n, _m} -> u end), data}
  end

  def handle_call({:update, data}, _from, data) do
    {:reply, :ok, data}
  end

  def handle_call({:update_motd, motd}, _from, data) do
    {:reply, :ok, put_in(data.motd, motd)}
  end

  def handle_call({:add_user, user}, _from, data) do
    if contains_user?(data, user) do
      {:reply, :already_added, data}
    else
      name = Chat.User.get(user).name
      mon = Process.monitor(user)
      {:reply, :ok, put_in(data.users, [{user, name, mon} | data.users])}
    end
  end

  def handle_call({:remove_user, user}, _from, data) do
    {removed, users} = Enum.partition(data.users, fn {u, _n, _m} -> u == user end)
    Enum.each(removed, fn {_u, _n, m} -> Process.demonitor(m) end)
    {:reply, ok_unless_empty(removed), put_in(data.users, users)}
  end

  def handle_call({:publish, msg, options}, _from, data) do
    case Keyword.get(options, :flush) do
      true -> GenEvent.sync_notify(data.event_manager, msg)
      _    -> GenEvent.notify(data.event_manager, msg)
    end
    {:reply, :ok, data}
  end

  def handle_call({:member?, user}, _from, data) do
    {:reply, contains_user?(data, user), data}
  end

  def handle_info({:DOWN, mon, :process, _pid, _reason}, data) do
    {removed, users} = Enum.partition(data.users, fn {_u, _n, m} -> m == mon end)
    [{_user, name, _ref}] = removed
    GenEvent.notify(data.event_manager, {:logout, name})
    {:noreply, put_in(data.users, users)}
  end

  def handle_info(_msg, data) do
    {:noreply, data}
  end

  defp contains_user?(data, user) do
    nil != Enum.find(data.users, fn {u, _n, _m} -> u == user end)
  end

  defp ok_unless_empty([]), do: :not_found
  defp ok_unless_empty(_),  do: :ok
end
