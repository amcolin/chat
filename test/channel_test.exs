defmodule Chat.Channel.Test do
  use ExUnit.Case, async: true

  alias Chat.Channel, as: Channel

  setup do
    {:ok, channel} = Channel.start_link(%Channel{name: "foo"})
    {:ok, %{channel: channel}}
  end

  test "channel data", %{channel: channel} do
    assert Channel.get(channel).name == "foo"
  end

  test "channel users", %{channel: channel} do
    {:ok, u1} = Chat.User.start_link(%Chat.User{name: "u1"})
    {:ok, u2} = Chat.User.start_link(%Chat.User{name: "u2"})

    assert Channel.users(channel) == []

    :ok = Channel.add_user(channel, u1)
    assert Channel.users(channel) == [u1]

    :already_added = Channel.add_user(channel, u1)
    assert Channel.users(channel) == [u1]

    :ok = Channel.add_user(channel, u2)
    assert Channel.users(channel) == [u2, u1]

    :ok = Channel.remove_user(channel, u1)
    assert Channel.users(channel) == [u2]

    :not_found = Channel.remove_user(channel, u1)
    assert Channel.users(channel) == [u2]

    :ok = Channel.remove_user(channel, u2)
    assert Channel.users(channel) == []

    :ok = Channel.add_user(channel, u2)
    :ok = Channel.add_user(channel, u1)
    assert Channel.users(channel) == [u1, u2]
    Agent.stop(u1)
    assert Channel.users(channel) == [u2]
    Agent.stop(u2)
    assert Channel.users(channel) == []
  end
end
