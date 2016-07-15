defmodule Chat.Test.ChannelSubscribeTest do
  use ExUnit.Case, async: false

  alias Chat.Channel, as: Channel
  alias Chat.Controller, as: Controller

  @tag :sync

  defmodule EventForwarder do
    use GenEvent
    def handle_event(event, pid) do
      send(pid, event)
      {:ok, pid}
    end
  end

  setup do
    Application.stop(:chat)
    :ok = Application.start(:chat)
  end

  test "pubsub" do
    {:ok, bob}   = Controller.new_user("bob")
    {:ok, alice} = Controller.new_user("alice")

    {:ok, ^bob, admin}    = Controller.join_channel("bob", "admin")
    {:ok, ^alice, ^admin} = Controller.join_channel("alice", "admin")

    Chat.Channel.subscribe(admin, EventForwarder, self)

    Channel.publish(admin, :msg1)
    assert_receive :msg1

    Channel.publish(admin, :msg2)
    assert_receive :msg2

    Channel.publish(admin, {:msg3, "test"}, [flush: true])
    assert_receive {:msg3, "test"}
  end
end