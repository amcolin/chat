defmodule Chat.Controller do
  @moduledoc """
  A controller that organizes the creation of chat users and the
  membership of chat channels.
  """

  use GenServer

  @name __MODULE__

  #
  # Client API
  #

  @doc """
  Start a chat controller process and link it to the calling process.
  """
  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: @name])
  end

  # @doc """
  # Create an empty user record with the requested `name`, and add it to the
  # registry. If a user with the same `name` already exists, return
  # {:already_created, pid}. Otherwise, return {:ok, pid}, where pid is the
  # id of the user process.
  # """
  def new_user(name) do
    GenServer.call(@name, {:new_user, name})
  end

  # @doc """
  # Create an empty channel record with the requested `name`, and add it to
  # the registry. If a channel with the same `name` already exists, return
  # {:already_created, pid}. Otherwise, return {:ok, pid}, where pid is the
  # id of the channel process.
  # """
  def new_channel(name) do
    GenServer.call(@name, {:new_channel, name})
  end

  # @doc """
  # Cause the `user` to join the `channel`. The `user` may be a pid or a
  # string name, as may the `channel`. If the channel is a string name and the
  # named channel does not yet exist, create it on the fly. Return {:ok, user,
  # channel} if successful. Return :user_not_found if the named user has not
  # been created. Return {:already_joined, user, channel} if the user was
  # already a member of the channel.
  # """
  def join_channel(user, channel) do
    GenServer.call(@name, {:join_channel, user, channel})
  end

  @doc """
  Cause the `user` to leave the `channel`. The `user` may be a pid or a string
  name, as may the `channel`. Return :user_not_found if the named user has not
  been created. Return :channel_not_found if the named channel has not been
  created. Return {:not_joined, user, channel} if the user was not a member of
  the channel. Otherwise return {:ok, user, channel}.
  """
  def leave_channel(user, channel) do
    GenServer.call(@name, {:leave_channel, user, channel})
  end

  @doc """
  Cause the `user` to say the public message `msg` in the `channel`. The
  `user` may be a pid or a string name, as may the `channel`. Return {:ok,
  user, channel} if successful. Return :user_not_found if the named user has
  not been created. Return :channel_not_found if the named channel has not
  been created. Return {:not_joined, user, channel} if the user is not a
  member of the channel.
  """
  def say_channel(user, channel, msg) do
    GenServer.call(@name, {:say_channel, user, channel, msg})
  end

  #
  # Server callbacks
  #

  defmodule State do
    defstruct id_counter: 0
  end

  def init(:ok) do
    {:ok, %State{}}
  end

  def handle_call({:new_user, name}, _from, state) do
    case Chat.Registry.whereis_name({:user, name}) do
      :undefined ->
        {:ok, pid} = Chat.User.Supervisor.start_user(name)
        Chat.Registry.register_name({:user, name}, pid)
        {:reply, {:ok, pid}, state}
      pid ->
        {:reply, {:already_created, pid}, state}
    end
  end

  def handle_call({:new_channel, name}, _from, state) do
    case Chat.Registry.whereis_name({:channel, name}) do
      :undefined ->
        {:reply, create_channel(name), state}
      pid ->
        {:reply, {:already_created, pid}, state}
    end
  end

  def handle_call({:generate_id}, _from, state) do
    id = state.id_counter + 1
    {:reply, {self, id}, put_in(state.id_counter, id)}
  end

  def handle_call({:join_channel, user, channel}, _from, state) do
    resolve_and_do(user, channel, state,
                   &do_join_channel/4, nil,
                   [create_channel: true])
  end

  def handle_call({:leave_channel, user, channel}, _from, state) do
    resolve_and_do(user, channel, state,
                   &do_leave_channel/4, nil)
  end

  def handle_call({:say_channel, user, channel, msg}, _from, state) do
    resolve_and_do(user, channel, state,
                   &do_say_channel/4, msg)
  end

  defp resolve_and_do(user, channel, state, fun, args, opts \\ []) do
    with {:ok, user}    <- resolve_user(user),
         {:ok, channel} <- resolve_channel(channel, opts) do
      fun.(user, channel, args, state)
    else
      error -> {:reply, error, state}
    end
  end

  defp resolve_user(user) when is_pid(user) do
    {:ok, user}
  end

  defp resolve_user(user) do
    case Chat.Registry.whereis_name({:user, user}) do
      :undefined -> :user_not_found
      user       -> {:ok, user}
    end
  end

  defp resolve_channel(channel, _opts) when is_pid(channel) do
    {:ok, channel}
  end

  defp resolve_channel(name, opts) do
    channel = Chat.Registry.whereis_name({:channel, name})
    create? = Keyword.get(opts, :create_channel)
    case {channel, create?} do
      {:undefined, true} -> create_channel(name)
      {:undefined, _}    -> :channel_not_found
      {channel, _}       -> {:ok, channel}
    end
  end

  defp create_channel(name) do
    {:ok, channel} = Chat.Channel.Supervisor.start_channel(name)
    Chat.Registry.register_name({:channel, name}, channel)
    {:ok, channel}
  end

  defp do_join_channel(user, channel, _args, state) do
    if Chat.Channel.member?(channel, user) do
      {:reply, {:already_joined, user, channel}, state}
    else
      Chat.User.add_channel(user, channel)
      Chat.Channel.add_user(channel, user)
      Chat.Channel.publish(channel, {:join, user})
      {:reply, {:ok, user, channel}, state}
    end
  end

  defp do_leave_channel(user, channel, _args, state) do
    if Chat.Channel.member?(channel, user) do
      Chat.Channel.publish(channel, {:leave, user})
      Chat.User.remove_channel(user, channel)
      Chat.Channel.remove_user(channel, user)
      {:reply, {:ok, user, channel}, state}
    else
      {:reply, {:not_joined, user, channel}, state}
    end
  end

  defp do_say_channel(user, channel, msg, state) do
    if Chat.Channel.member?(channel, user) do
      Chat.Channel.publish(channel, {:say, user, msg})
      {:reply, {:ok, user, channel}, state}
    else
      {:reply, {:not_joined, user, channel}, state}
    end
  end
end
