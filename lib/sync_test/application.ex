defmodule SyncTest.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SyncTestWeb.Telemetry,
      SyncTest.Repo,
      {DNSCluster, query: Application.get_env(:sync_test, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: SyncTest.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: SyncTest.Finch},
      # Start a worker by calling: SyncTest.Worker.start_link(arg)
      # {SyncTest.Worker, arg},
      # Start to serve requests, typically the last entry
      SyncTestWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SyncTest.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    SyncTestWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
