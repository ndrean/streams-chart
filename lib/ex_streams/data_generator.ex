defmodule ExStreams.DataGenerator do
  @moduledoc """
  GenServer that generates streaming data using Elixir Streams
  """
  use GenServer, restart: :transient

  @topic "data_stream"

  defstruct [:stream_pid, :data_count, :start_time, :is_running, :genserver_pid, :interval]

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_stream(interval \\ 500) do
    GenServer.call(__MODULE__, {:start_stream, interval})
  end

  def stop_stream do
    GenServer.call(__MODULE__, :stop_stream)
  end

  def get_status do
    GenServer.call(__MODULE__, :get_status)
  end

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{data_count: 0, is_running: false, genserver_pid: self()}}
  end

  @impl true
  def handle_call({:start_stream, interval}, _from, state) do
    if state.is_running do
      {:reply, {:error, :already_running}, state}
    else
      # Create an infinite stream of sensor data
      sensor_stream =
        create_sensor_stream(interval, state.genserver_pid)

      {:ok, task_pid} =
        Task.start(fn -> process_stream(sensor_stream) end)

      Process.monitor(task_pid)

      new_state = %{
        state
        | start_time: System.monotonic_time(:millisecond),
          is_running: true,
          data_count: 0,
          stream_pid: task_pid,
          interval: interval
      }

      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:stop_stream, _from, state) do
    if state.stream_pid && Process.alive?(state.stream_pid) do
      Process.exit(state.stream_pid, :shutdown)
    end

    new_state = %{state | stream_pid: nil, is_running: false}
    :ok = Phoenix.PubSub.broadcast(:pubsub, @topic, {:stream_stopped})

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_status, _from, state) do
    status = %{
      is_running: state.is_running,
      data_count: state.data_count,
      uptime:
        if(state.start_time, do: System.monotonic_time(:millisecond) - state.start_time, else: 0)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info({:data_generated, data}, state) do
    # Broadcast the data to LiveView
    Phoenix.PubSub.broadcast(:pubsub, @topic, {:new_data, data})

    new_state = %{state | data_count: state.data_count + 1}
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Handle :shutdown or other exit reasons
    {:noreply, state}
  end

  @impl true
  def handle_info(_msg, state), do: {:noreply, state}

  # Private functions

  defp create_sensor_stream(interval, genserver_pid) do
    Stream.iterate(1, &(&1 + 1))
    |> Stream.map(fn id ->
      %{
        id: id,
        timestamp: DateTime.utc_now(),
        temperature: 20.0 + :rand.uniform() * 10
      }
    end)
    |> Stream.each(fn data ->
      send(genserver_pid, {:data_generated, data})
      Process.sleep(interval)
    end)
  end

  defp process_stream(stream) do
    stream
    # Group into batches of 5
    |> Stream.chunk_every(5)
    |> Stream.with_index()
    |> Enum.each(fn {batch, batch_index} ->
      avg_temp =
        batch
        |> Enum.map(& &1.temperature)
        |> Enum.sum()
        |> Kernel./(length(batch))

      batch_summary =
        %{
          id: batch_index + 1,
          count: length(batch),
          avg_temperature: Float.round(avg_temp, 2),
          items: batch
        }

      Phoenix.PubSub.broadcast(
        :pubsub,
        "data_stream",
        {:batch_processed, batch_summary}
      )
    end)
  end

  @impl true
  def terminate(reason, _state) do
    IO.inspect(reason, label: "DataGenerator terminated with reason: ")
    :ok
  end
end
