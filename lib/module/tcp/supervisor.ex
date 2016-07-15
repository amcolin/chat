defmodule Module.TCP.Supervisor do
  use Supervisor

  @name __MODULE__

  def start_link do
    Supervisor.start_link(__MODULE__, :ok, [name: @name])
  end

  def start_input(socket) do
    {:ok, pid} = Task.Supervisor.start_child(Module.TCP.TaskSupervisor,
                                             Module.TCP.Connection, :login,
                                             [socket])
    :ok = :gen_tcp.controlling_process(socket, pid)
    {:ok, pid}
  end

  def init(:ok) do
    port = Application.fetch_env!(:chat, :tcp_listen_port)
    children = [
      supervisor(Task.Supervisor, [[name: Module.TCP.TaskSupervisor]]),
      worker(Task, [Module.TCP.Listener, :listen, [port]])
    ]
    supervise(children, strategy: :one_for_one)
  end
end
