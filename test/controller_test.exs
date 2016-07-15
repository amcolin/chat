defmodule Chat.ControllerTest do
  use ExUnit.Case, async: false

  alias Chat.Controller, as: Controller

  @moduletag :capture_log
  @tag :sync

  setup do
    Application.stop(:chat)
    :ok = Application.start(:chat)
  end

  test "user creation" do
    {:ok, bob}   = Controller.new_user("bob")
    {:ok, alice} = Controller.new_user("alice")

    assert Chat.User.get(bob).name   == "bob"
    assert Chat.User.get(alice).name == "alice"

    assert Chat.Registry.whereis_name({:user, "bob"})   == bob
    assert Chat.Registry.whereis_name({:user, "alice"}) == alice

    assert Controller.new_user("bob")   == {:already_created, bob}
    assert Controller.new_user("alice") == {:already_created, alice}
  end

  test "channel joins and leaves" do
    {:ok, bob}   = Controller.new_user("bob")
    {:ok, alice} = Controller.new_user("alice")

    {:ok, ^bob, admin}    = Controller.join_channel(bob, "admin")
    {:ok, ^alice, ^admin} = Controller.join_channel(alice, "admin")

    ^admin  = Chat.Registry.whereis_name({:channel, "admin"})
    "admin" = Chat.Channel.get(admin).name

    true = Chat.Channel.member?(admin, bob)
    true = Chat.Channel.member?(admin, alice)

    {:already_joined, ^bob, ^admin}   = Controller.join_channel("bob", "admin")
    {:already_joined, ^alice, ^admin} = Controller.join_channel("alice", "admin")
    {:already_joined, ^bob, ^admin}   = Controller.join_channel("bob", admin)
    {:already_joined, ^alice, ^admin} = Controller.join_channel("alice", admin)
    {:already_joined, ^bob, ^admin}   = Controller.join_channel(bob, "admin")
    {:already_joined, ^alice, ^admin} = Controller.join_channel(alice, "admin")
    {:already_joined, ^bob, ^admin}   = Controller.join_channel(bob, admin)
    {:already_joined, ^alice, ^admin} = Controller.join_channel(alice, admin)

    :user_not_found    = Controller.join_channel("eve", "admin")
    :user_not_found    = Controller.leave_channel("eve", "admin")
    :channel_not_found = Controller.leave_channel("alice", "missing")

    {:ok, ^bob, ^admin} = Controller.leave_channel("bob", "admin")
    false = Chat.Channel.member?(admin, bob)
    true = Chat.Channel.member?(admin, alice)

    {:not_joined, ^bob, ^admin} = Controller.leave_channel("bob", "admin")

    {:ok, ^alice, ^admin} = Controller.leave_channel("alice", "admin")
    false = Chat.Channel.member?(admin, bob)
    false = Chat.Channel.member?(admin, alice)
  end
end
