defmodule ExStreams.BinanceClient do
  # use GenServer
  use WebSockex, restart: :transient

  require Logger

  def start_link(url: url, topic: topic) do
    true =
      :ets.insert(:binance_data, {:price, 0})

    {:ok, _pid} = WebSockex.start_link(url, __MODULE__, topic: topic)
  end

  @impl true
  def handle_connect(conn, state) do
    Logger.info("[Binance Socket] Connected to #{conn.host} with state: #{inspect(state)}")

    {:ok, state}
  end

  @impl true
  def handle_frame({:text, msg}, [topic: topic] = state) do
    %{"p" => p} = Jason.decode!(msg)
    {new_price, _} = Float.parse(p)
    data = %{id: System.os_time(:microsecond), p: new_price}

    # step = 0.005
    # [price: last_price] = :ets.lookup(:binance_data, :price)

    # change =
    #   if last_price == 0 do
    #     0
    #   else
    #     # Calculate the change as a percentage of the last price
    #     Float.round((last_price - new_price) / last_price * 1_000_000, 4)
    #     |> dbg()
    #     |> case do
    #       v when v > step -> 1
    #       v when v < -step -> -1
    #       _ -> 0
    #     end
    #   end

    true =
      :ets.insert(:binance_data, {:price, new_price})

    :ok =
      Phoenix.PubSub.broadcast(
        :pubsub,
        topic,
        {:new_data, data, 1}
      )

    {:ok, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("[Binance Socket] terminating: #{inspect(reason)}")
  end
end
