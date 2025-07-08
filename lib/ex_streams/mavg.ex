defmodule ExStreams.Mavg do
  use GenServer, restart: :transient

  require Logger

  # Client API
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def get_history do
    GenServer.call(__MODULE__, :get_history)
  end

  def clear do
    GenServer.cast(__MODULE__, :clear)
  end

  # Server Callbacks
  @impl true
  def init(opts) do
    opts_map = for {k, v} <- opts, into: %{}, do: {k, v}
    Phoenix.PubSub.subscribe(:pubsub, opts_map.binance_stream)

    {:ok,
     Map.merge(opts_map, %{
       length: 0,
       intermediate_average: nil,
       halt: true
     })}
  end

  @impl true
  def handle_cast(:clear, state) do
    new_state =
      %{
        state
        | length: 0,
          intermediate_average: nil,
          halt: true
      }

    {:noreply, new_state}
  end

  @impl true

  def handle_info({:new_data, _, _}, %{halt: true} = state) do
    Logger.debug("[Halted]: -- Receive new data while halted, ignoring", ansi_color: :magenta)
    {:noreply, state}
  end

  def handle_info({:new_data, data, _}, state) do
    new_intermediate_average =
      case state.intermediate_average do
        nil -> data.p
        v -> (v * state.length + data.p) / (state.length + 1)
      end

    new_state =
      %{
        state
        | length: state.length + 1,
          intermediate_average: new_intermediate_average
      }

    {:noreply, new_state}
  end

  def handle_info(:broadcast_average, %{length: length} = state) when length > 0 do
    Logger.info("[Mavg] --> Received: #{length} ", ansi_color: :green)
    current_time = System.os_time(:microsecond)
    new_moving_avg = state.intermediate_average |> Float.round(2)

    new_point = %{
      col_a: current_time,
      col_b: new_moving_avg
    }

    :ok =
      Phoenix.PubSub.broadcast(
        :pubsub,
        state.send_topic,
        {:new_average_point, new_point, state.length}
      )

    # Schedule broadcast only when starting a new accumulation period
    unless state.halt, do: Process.send_after(self(), :broadcast_average, state.period)

    new_state =
      %{
        state
        | intermediate_average: nil,
          length: 0
      }

    {:noreply, new_state}
  end

  def handle_info(:broadcast_average, state) do
    {:noreply, state}
  end

  def handle_info(:halt, state) do
    Logger.info("[Mavg] Halting moving average calculations")
    {:noreply, %{state | halt: true}}
  end

  def handle_info(:resume, state) do
    Logger.info("[Mavg] Starting moving average calculations with period: #{state.period}")
    Process.send_after(self(), :broadcast_average, state.period)
    {:noreply, %{state | halt: false}}
  end

  @impl true
  def handle_call(:get_history, _from, state) do
    {:reply, state.averages, state}
  end

  @impl true
  def terminate(reason, _state) do
    Logger.info("[Mavg] terminating: #{inspect(reason)}")
  end
end
