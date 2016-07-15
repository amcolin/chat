defmodule Chat.Mixfile do
  use Mix.Project

  def project do
    [
      app: :chat,
      version: "0.1.0",
      elixir: "~> 1.3",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      applications: [:logger, :runtime_tools],
      env: [tcp_listen_port: 4040],
      mod: {Chat, []}
    ]
  end

  defp deps do
    [{:exrm, "~> 1.0"}]
  end
end
