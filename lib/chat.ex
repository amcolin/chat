defmodule Chat do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      supervisor(Chat.Supervisor, []),
      supervisor(Module.Supervisor, [])
    ]

    opts = [strategy: :rest_for_one, name: App.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
