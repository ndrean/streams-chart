defmodule ExStreams.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :binance_data =
      :ets.new(:binance_data, [:public, :named_table])

    children = [
      ExStreamsWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:ex_streams, :dns_cluster_query) || :ignore},
      {DynamicSupervisor, name: DynSup, strategy: :one_for_one},
      {Phoenix.PubSub, name: :pubsub},
      ExStreams.DataGenerator,
      ExStreamsWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ExStreams.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ExStreamsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
