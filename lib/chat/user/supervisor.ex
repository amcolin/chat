defmodule Chat.User.Supervisor do
  use Supervisor

  @name __MODULE__

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: @name])
  end

  def start_user(name) when is_binary(name) do
    Supervisor.start_child(@name, [%Chat.User{name: name}])
  end

  def init(:ok) do
    children = [
      worker(Chat.User, [], [restart: :temporary])
    ]
    supervise(children, strategy: :simple_one_for_one)
  end
end
