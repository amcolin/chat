defmodule Chat.Supervisor do
  use Supervisor

  @name __MODULE__

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: @name])
  end

  def init(:ok) do
    children = [
      worker(Chat.Registry, []),
      supervisor(Chat.User.Supervisor, []),
      supervisor(Chat.Channel.Supervisor, []),
      worker(Chat.Controller, [])
    ]
    supervise(children, strategy: :rest_for_one)
  end
end