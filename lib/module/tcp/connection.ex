defmodule Module.TCP.Connection do
  @moduledoc """
  This module processes I/O from a single TCP client connection, converting
  text input into commands to issue against the chat process_inputr.
  """

  def login(socket) do
    write(socket, "Enter your name: ")
    with {:ok, line} <- read_line(socket),
         {:ok, name} <- process_name(line),
         {:ok, user} <- create_user(socket, name) do
      process_input(socket, user)
    else
      {:try_again, reason} ->
        write_line(socket, "Invalid login. " <> reason)
        login(socket)
      _ ->
        exit(:shutdown)
    end
  end

  defp process_name(line) do
    name = String.trim(line)
    len  = String.length(name)
    cond do
      len < 4 ->
        {:try_again, "Too short."}
      len > 20 ->
        {:try_again, "Too long."}
      String.match?(name, ~r/[^a-zA-Z]/) ->
        {:try_again, "Contains invalid characters."}
      true ->
        {:ok, name}
    end
  end

  defp create_user(socket, name) do
    case Chat.Controller.new_user(name) do
      {:ok, user} ->
        Process.link(user)    # TODO: Possible race condition
        write_line(socket, "Welcome, #{name}.")
        join_channel(socket, user, "admin")
        {:ok, user}
      {:already_created, _user} ->
        {:try_again, "Already logged in."}
    end
  end

  defp join_channel(socket, user, channel) do
    {:ok, ^user, channel} = Chat.Controller.join_channel(user, channel)
    Task.start_link(fn -> process_feed(socket, channel, user) end)
  end

  defp process_input(socket, user) do
    case read_line(socket) do
      {:ok, msg} ->
        Chat.Controller.say_channel(user, "admin", String.trim(msg))
        process_input(socket, user)
      _ ->
        exit(:shutdown)
    end
  end

  defp process_feed(socket, channel, user) do
    stream = Chat.Channel.subscribe(channel)
    for msg <- stream, do: process_msg(socket, channel, user, msg)
  end

  defp process_msg(socket, channel, _user, {:say, speaker, msg}) do
    cdata = Chat.Channel.get(channel)
    sdata = Chat.User.get(speaker)
    write_line(socket, "[#{cdata.name}] #{sdata.name}: #{msg}")
  end

  defp process_msg(socket, channel, _user, {:join, speaker}) do
    cdata = Chat.Channel.get(channel)
    sdata = Chat.User.get(speaker)
    write_line(socket, "[#{cdata.name}] #{sdata.name} just joined the channel.")
  end

  defp process_msg(socket, channel, _user, {:leave, speaker}) do
    cdata = Chat.Channel.get(channel)
    sdata = Chat.User.get(speaker)
    write_line(socket, "[#{cdata.name}] #{sdata.name} just left the channel.")
  end

  defp process_msg(socket, channel, _user, {:logout, uname}) do
    cdata = Chat.Channel.get(channel)
    write_line(socket, "[#{cdata.name}] #{uname} disconnected.")
  end

  defp process_msg(_socket, _channel, _user, _msg) do
    # Ignore unhandled messages
  end

  defp write(socket, msg) do
    :gen_tcp.send(socket, msg)
  end

  defp write_line(socket, msg) do
    :gen_tcp.send(socket, msg <> "\r\n")
  end

  defp read_line(socket) do
    :gen_tcp.recv(socket, 0)
  end
end
