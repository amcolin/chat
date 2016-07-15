defmodule Module.TCP.Listener do
  @moduledoc """
  This module starts listening on the configured socket port for connection to
  the chat server. When client connections arrive, it starts up new tasks to
  handle I/O with the client.
  """

  @name __MODULE__

  def listen(port) do
    opts = [:binary, packet: :line, active: false, reuseaddr: true]
    {:ok, socket} = :gen_tcp.listen(port, opts)
    accept_loop(socket)
  end

  defp accept_loop(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    {:ok, _pid} = Module.TCP.Supervisor.start_input(socket)
    accept_loop(listen_socket)
  end
end
