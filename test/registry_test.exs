defmodule Chat.RegistryTest do
  use ExUnit.Case, async: true

  alias Chat.Registry, as: Registry

  setup do
    Registry.start_link
    Agent.start_link(fn -> [] end, name: :agent)
    :ok
  end

  test "registry updates" do
    agent = Process.whereis(:agent)

    assert Registry.whereis_name(:foo) == :undefined

    assert Registry.register_name(:foo, agent) == :yes
    assert Registry.whereis_name(:foo) == agent

    assert Registry.register_name(:foo, agent) == :no
    assert Registry.whereis_name(:foo) == agent

    assert Registry.unregister_name(:foo) == :ok
    assert Registry.whereis_name(:foo) == :undefined
  end

  test "process monitor" do
    agent = Process.whereis(:agent)

    Registry.register_name(:foo, agent)
    assert Registry.whereis_name(:foo) == agent

    Agent.stop(agent, :normal)
    assert Registry.whereis_name(:foo) == :undefined
  end
end
