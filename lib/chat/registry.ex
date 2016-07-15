defmodule Chat.Registry do
  @moduledoc """
  This registry stores mappings between string-based user and channel names
  and their processes.
  """
  use GenServer

  @reg_name __MODULE__

  #
  # Client API
  #

  @doc """
  Start the registry server process, but don't link it to the calling process.
  """
  def start do
    GenServer.start(__MODULE__, :ok, [name: @reg_name])
  end

  @doc """
  Start the registry server process, and link it to the calling process.
  """
  def start_link do
    GenServer.start_link(__MODULE__, :ok, [name: @reg_name])
  end

  @doc """
  Return the pid with the registered name `name`. Return :undefined if
  the name is not registered.
  """
  def whereis_name(name) do
    GenServer.call(@reg_name, {:whereis, name})
  end

  @doc """
  Associate the name `name` with the process id `pid`. If the process ever
  terminates, the association will be removed automatically. Return :yes if a
  new association was created. Otherwise return :no.
  """
  def register_name(name, pid) when not is_pid(name) and is_pid(pid) do
    GenServer.call(@reg_name, {:register, name, pid})
  end

  @doc """
  Remove the association between the name `name` and it currently registered
  process id `pid`.  Return :ok.
  """
  def unregister_name(name) do
    GenServer.call(@reg_name, {:unregister, name})
  end

  @doc """
  Send the message `msg` to the process registered under the name `name`.
  """
  def send(name, msg) do
    case whereis_name(name) do
      :undefined ->
        {:badarg, {name, msg}}
      pid ->
        Kernel.send(pid, msg)
        pid
    end
  end

  #
  # Server callbacks
  #

  defmodule State do
    defstruct processes: %{},  # name => {pid, monitor}
              monitors:  %{}   # monitor => name
  end

  def init(:ok) do
    {:ok, %State{}}
  end

  def handle_call({:whereis, name}, _from, state) do
    case Map.get(state.processes, name) do
      {pid, _mon} -> {:reply, pid, state}
      nil         -> {:reply, :undefined, state}
    end
  end

  def handle_call({:register, name, pid}, _from, state) do
    if Map.has_key?(state.processes, name) do
      {:reply, :no, state}
    else
      mon = Process.monitor(pid)
      state = put_in(state.processes, Map.put(state.processes, name, {pid, mon}))
      state = put_in(state.monitors, Map.put(state.monitors, mon, name))
      {:reply, :yes, state}
    end
  end

  def handle_call({:unregister, name}, _from, state) do
    case Map.get(state.processes, name) do
      nil ->
        {:reply, :ok, state}
      {_pid, mon} ->
        Process.demonitor(mon)
        state = put_in(state.processes, Map.delete(state.processes, name))
        state = put_in(state.monitors, Map.delete(state.monitors, mon))
        {:reply, :ok, state}
    end
  end

  def handle_info({:DOWN, mon, :process, pid, _reason}, state) do
    {name, monitors} = Map.pop(state.monitors, mon)
    {{^pid, ^mon}, processes} = Map.pop(state.processes, name)
    state = put_in(state.processes, processes)
    state = put_in(state.monitors, monitors)
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end
end
