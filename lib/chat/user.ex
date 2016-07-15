defmodule Chat.User do
  @moduledoc """
  A process holding a chat user's state.
  """

  use GenServer

  defstruct name: "",
            channels: []  # [{pid, name, monitor}, ...]

  #
  # Client API
  #

  @doc """
  Start a new user process, and initialize its data to `data`
  (type=%Chat.User). This function should be called only by the controller.
  """
  def start_link(data) do
    GenServer.start_link(__MODULE__, data)
  end

  @doc """
  Stop the `user` process, destroying its data.
  """
  def stop(user) do
    GenServer.stop(user, :normal)
  end

  @doc """
  Return the data associated with the `user`.
  """
  def get(user) do
    GenServer.call(user, {:get})
  end

  @doc """
  Return a list containing the channels the `user` has joined.
  """
  def channels(user) do
    GenServer.call(user, {:channels})
  end

  @doc """
  Update the `user` process's `data`.
  """
  def update(user, data) do
    GenServer.call(user, {:update, data})
  end

  @doc """
  Add the `channel` to the user's current list of active channels.
  This starts a process monitor on the channel so the user will be removed
  from the channel if the channel process dies. Return :already_added if
  the user has already been added to the channel. Otherwise return :ok.
  """
  def add_channel(user, channel) do
    GenServer.call(user, {:add_channel, channel})
  end

  @doc """
  Remove the `channel` from the `user`'s list of active channels. Return
  :not_found if the channel was not found on the user's list. Otherwise
  return :ok.
  """
  def remove_channel(user, channel) do
    GenServer.call(user, {:remove_channel, channel})
  end

  #
  # Server callbacks
  #

  def init(data) do
    {:ok, data}
  end

  def handle_call({:get}, _from, data) do
    {:reply, data, data}
  end

  def handle_call({:channels}, _from, data) do
    {:reply, Enum.map(data.channels, fn {c, _n, _m} -> c end), data}
  end

  def handle_call({:update, data}, _from, _data) do
    {:reply, :ok, data}
  end

  def handle_call({:add_channel, channel}, _from, data) do
    if contains_channel?(data, channel) do
      {:reply, :already_added, data}
    else
      name = Chat.Channel.get(channel).name
      mon = Process.monitor(channel)
      {:reply, :ok, put_in(data.channels, [{channel, name, mon} | data.channels])}
    end
  end

  def handle_call({:remove_channel, channel}, _from, data) do
    {removed, channels} = Enum.partition(data.channels, fn {c, _n, _m} -> c == channel end)
    Enum.each(removed, fn {_c, _n, m} -> Process.demonitor(m) end)
    {:reply, ok_unless_empty(removed), put_in(data.channels, channels)}
  end

  def handle_info({:DOWN, mon, :process, _pid, _reason}, data) do
    {removed, channels} = Enum.partition(data.channels, fn {_c, _n, m} -> m == mon end)
    [{_c, _name, _m}] = removed
    # TODO: Notify the user that the channel disappeared.
    {:noreply, put_in(data.channels, channels)}
  end

  def handle_info(_msg, data) do
    {:noreply, data}
  end

  defp contains_channel?(data, channel) do
    nil != Enum.find(data.channels, fn {c, _n, _m} -> c == channel end)
  end

  defp ok_unless_empty([]), do: :not_found
  defp ok_unless_empty(_),  do: :ok
end
