defmodule Chat.Channel.Supervisor do
  use Supervisor

  @name __MODULE__

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: @name])
  end

  def start_channel(name) when is_binary(name) do
    Supervisor.start_child(@name, [%Chat.Channel{name: name}])
  end

  def init(:ok) do
    children = [
      worker(Chat.Channel, [], [restart: :temporary])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
