defmodule ExStreamsWeb.StreamLive do
  use ExStreamsWeb, :live_view
  alias ExStreams.DataGenerator
  require Logger

  @topic "data_stream"

  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(:pubsub, @topic)
    end

    initial_socket =
      socket
      |> assign(:env, Application.fetch_env!(:ex_streams, :env))
      |> assign(:is_streaming, false)
      |> assign(:total_data_points, 0)
      |> assign(:total_batches, 0)
      |> assign(:avg_temperature, 0.0)
      |> assign(:last_batch, nil)
      |> assign(:stream_interval, 1_000)
      |> assign(:chart_data, [])
      |> stream(:sensor_data, [])
      |> stream(:batch_summaries, [])

    {:ok, initial_socket}
  end

  def handle_event("start_stream", _params, socket) do
    case DataGenerator.start_stream(socket.assigns.stream_interval) do
      :ok ->
        {:noreply, assign(socket, :is_streaming, true)}

      {:error, :already_running} ->
        send(self(), "stop_stream")

        {:noreply,
         put_flash(
           socket,
           :error,
           "Stream was already running. It will be stopped and restarted."
         )}
    end
  end

  def handle_event("stop_stream", _params, socket) do
    DataGenerator.stop_stream()
    {:noreply, assign(socket, :is_streaming, false)}
  end

  def handle_event("update_interval", %{"interval" => interval}, socket) do
    interval_int = String.to_integer(interval)
    {:noreply, assign(socket, :stream_interval, interval_int)}
  end

  def handle_event("clear_data", _params, socket) do
    {:noreply,
     socket
     |> stream(:sensor_data, [], reset: true)
     |> stream(:batch_summaries, [], reset: true)
     |> assign(:total_data_points, 0)
     |> assign(:total_batches, 0)
     |> assign(:last_batch, [])
     |> assign(:avg_temperature, 0.0)
     |> assign(:is_streaming, false)
     |> assign(:chart_data, [])}
  end

  def handle_info("stop_stream", _params, socket) do
    DataGenerator.stop_stream()
    {:noreply, assign(socket, :is_streaming, false)}
  end

  def handle_info({:stream_stopped}, socket) do
    {:noreply, assign(socket, :is_streaming, false)}
  end

  def handle_info({:new_data, data}, socket) do
    # Add to sensor data stream (LiveView will automatically update the DOM)
    updated_socket =
      socket
      |> stream_insert(:sensor_data, data, at: 0)
      |> update(:total_data_points, &(&1 + 1))

    # Keep only the last 20 items in the chart for performance
    new_chart_point = %{
      id: data.id,
      temperature: data.temperature,
      timestamp: DateTime.to_unix(data.timestamp, :millisecond)
    }

    new_chart_data =
      (socket.assigns.chart_data ++ [new_chart_point])
      |> Enum.take(20)

    {:noreply, assign(updated_socket, :chart_data, new_chart_data)}
  end

  def handle_info({:batch_processed, batch_summary}, socket) do
    updated_socket =
      socket
      |> stream_insert(:batch_summaries, batch_summary, at: 0)
      |> update(:total_batches, &(&1 + 1))
      |> assign(:last_batch, batch_summary)

    # Update running average temperature
    new_avg =
      calculate_running_average(
        socket.assigns.avg_temperature,
        socket.assigns.total_batches,
        batch_summary.avg_temperature
      )

    {:noreply, assign(updated_socket, :avg_temperature, new_avg)}
  end

  defp calculate_running_average(_current_avg, count, new_value) when count <= 1 do
    new_value
  end

  defp calculate_running_average(current_avg, count, new_value) do
    (current_avg * (count - 1) + new_value) / count
  end

  defp get_temperature_class(temp) when temp < 25, do: "cold-gradient"
  defp get_temperature_class(temp) when temp > 30, do: "hot-gradient"
  defp get_temperature_class(_), do: "gradient-bar"

  defp calculate_bar_height(temperature) do
    min(max((temperature - 15) * 16, 10), 280)
  end

  def render(assigns) do
    ~H"""
    <div class="min-h-screen bg-gradient-to-br from-blue-900 via-purple-900 to-indigo-900 text-white">
      <div class="container mx-auto px-4 py-8">
        <h1 class="text-4xl font-bold text-center mb-8 text-transparent bg-clip-text bg-gradient-to-r from-cyan-400 to-purple-400">
          🌊 Elixir Streams + Phoenix LiveView
        </h1>
        
    <!-- Controls Section -->
        <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 mb-8 border border-white/20">
          <h2 class="text-2xl font-semibold mb-4 text-yellow-300">Stream Controls</h2>

          <div class="flex flex-wrap items-center gap-4 mb-4">
            <button
              phx-click="start_stream"
              disabled={@is_streaming}
              class="px-6 py-3 bg-gradient-to-r from-green-500 to-emerald-600 rounded-lg font-semibold
                     hover:from-green-600 hover:to-emerald-700 disabled:opacity-50 disabled:cursor-not-allowed
                     transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-1"
            >
              {if @is_streaming, do: "🟢 Streaming...", else: "▶️ Start Stream"}
            </button>

            <button
              phx-click="stop_stream"
              disabled={!@is_streaming}
              class="px-6 py-3 bg-gradient-to-r from-red-500 to-pink-600 rounded-lg font-semibold
                     hover:from-red-600 hover:to-pink-700 disabled:opacity-50 disabled:cursor-not-allowed
                     transition-all duration-200 shadow-lg hover:shadow-xl transform hover:-translate-y-1"
            >
              ⏹️ Stop Stream
            </button>

            <button
              phx-click="clear_data"
              class="px-6 py-3 bg-gradient-to-r from-gray-500 to-gray-600 rounded-lg font-semibold
                     hover:from-gray-600 hover:to-gray-700 transition-all duration-200 shadow-lg
                     hover:shadow-xl transform hover:-translate-y-1"
            >
              🗑️ Clear Data
            </button>
          </div>

          <div class="flex items-center gap-4">
            <form phx-change="update_interval" id="interval-form">
              <label class="text-sm font-medium">Interval:</label>
              <input
                type="range"
                min="100"
                max="2000"
                step="100"
                disabled={@is_streaming}
                value={@stream_interval}
                phx-change="update_interval"
                name="interval"
                class="flex-1 max-w-xs"
              />
              <span class="text-sm bg-white/20 px-3 py-1 rounded-full">
                {@stream_interval}ms
              </span>
            </form>
          </div>
        </div>
        
    <!-- Statistics Dashboard -->
        <div class="grid grid-cols-1 md:grid-cols-4 gap-4 mb-8">
          <div class="bg-white/10 backdrop-blur-md rounded-xl p-4 border border-white/20">
            <div class="text-3xl font-bold text-cyan-400">{@total_data_points}</div>
            <div class="text-sm text-gray-300">Data Points</div>
          </div>

          <div class="bg-white/10 backdrop-blur-md rounded-xl p-4 border border-white/20">
            <div class="text-3xl font-bold text-green-400">{@total_batches}</div>
            <div class="text-sm text-gray-300">Batches Processed</div>
          </div>

          <div class="bg-white/10 backdrop-blur-md rounded-xl p-4 border border-white/20">
            <div class="text-3xl font-bold text-orange-400">
              {Float.round(@avg_temperature, 1)}°C
            </div>
            <div class="text-sm text-gray-300">Avg Temperature</div>
          </div>

          <div class="bg-white/10 backdrop-blur-md rounded-xl p-4 border border-white/20">
            <div class="text-3xl font-bold text-purple-400">
              {if @is_streaming, do: "🟢 Live", else: "🔴 Stopped"}
            </div>
            <div class="text-sm text-gray-300">Stream Status</div>
          </div>
        </div>
        <!-- Real-time Chart -->
        <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 mb-8 border border-white/20 shadow-2xl">
          <div class="flex items-center justify-between mb-6">
            <h3 class="text-2xl font-bold text-yellow-300 flex items-center gap-2">
              🌡️ Live Temperature Chart
            </h3>
            <div class="flex items-center gap-4 text-sm text-gray-300">
              <!-- Legend here -->
            </div>
          </div>

          <div class="relative h-80 bg-black/20 rounded-lg p-4 overflow-hidden">
            <!-- Y-axis labels -->
            <div class="absolute left-0 top-0 h-full w-8 flex flex-col justify-between text-xs text-gray-400 py-4">
              <span>35°C</span>
              <span>30°C</span>
              <span>25°C</span>
              <span>20°C</span>
              <span>15°C</span>
            </div>

            <div class="ml-8 h-full flex items-end justify-center space-x-1">
              <%= if Enum.empty?(@chart_data) do %>
                <div class="text-center text-gray-400 w-full flex items-center justify-center">
                  <div class="text-center">
                    <div class="text-4xl mb-2">📊</div>
                    <div>Start streaming to see live temperature data</div>
                  </div>
                </div>
              <% else %>
                <div
                  :for={point <- @chart_data}
                  id={"point-#{point.id}"}
                  class={"min-w-[12px] flex-1 max-w-6 rounded-t-lg shadow-lg
                  transition-all duration-500 hover:scale-105 hover:shadow-xl
                  #{get_temperature_class(point.temperature)}"}
                  style={"height: #{calculate_bar_height(point.temperature)}px"}
                  title={"#{Float.round(point.temperature, 1)}°C"}
                >
                </div>
              <% end %>
            </div>
          </div>
        </div>

        <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <!-- Live Sensor Data Stream -->
          <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20">
            <h3 class="text-xl font-semibold mb-4 text-yellow-300">📊 Live Sensor Data</h3>
            <div class="space-y-2 max-h-96 overflow-y-auto">
              <div id="sensor-data-stream" phx-update="stream" class="space-y-2">
                <div
                  :for={{dom_id, data} <- @streams.sensor_data}
                  id={dom_id}
                  class="p-3 bg-black/30 rounded-lg border border-white/10
                         animate-pulse hover:bg-black/40 transition-colors"
                >
                  <div class="flex justify-between items-center">
                    <div class="text-xs text-gray-400">
                      {Calendar.strftime(data.timestamp, "%H:%M:%S")}
                    </div>
                  </div>
                  <div class="grid grid-cols-3 gap-2 mt-2 text-sm">
                    <div>
                      🌡️ {Float.round(data.temperature, 1)}°C
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          
    <!-- Batch Processing Results -->
          <div class="bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20">
            <h3 class="text-xl font-semibold mb-4 text-yellow-300">📦 Batch Processing</h3>
            <div class="space-y-2 max-h-96 overflow-y-auto">
              <div id="batch-summaries-stream" phx-update="stream" class="space-y-2">
                <div
                  :for={{dom_id, batch} <- @streams.batch_summaries}
                  id={dom_id}
                  class="p-4 bg-black/30 rounded-lg border border-white/10
                         hover:bg-black/40 transition-colors"
                >
                  <div class="flex justify-between items-center mb-2">
                    <div class="font-semibold text-green-300">
                      Batch #{batch.id}
                    </div>
                    <div class="text-sm text-orange-300">
                      {batch.count} items
                    </div>
                  </div>
                  <div class="text-sm text-gray-300">
                    Avg Temperature:
                    <span class="text-yellow-300 font-semibold">
                      {batch.avg_temperature}°C
                    </span>
                  </div>
                  <div class="mt-2 text-xs text-gray-400">
                    Processing {batch.count} sensor readings using Elixir Streams
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
        
    <!-- Stream Processing Info -->
        <div class="mt-8 bg-white/10 backdrop-blur-md rounded-xl p-6 border border-white/20">
          <h3 class="text-xl font-semibold mb-4 text-yellow-300">🔧 Stream Processing Pipeline</h3>
          <p>
            <ul>
              <li>Stream.iterate/2 → Stream.map/2 creates infinite sensor data</li>
              <li>Stream.chunk_every/2 groups data into batches of 5</li>
              <li>Phoenix.PubSub broadcasts to LiveView streams</li>
            </ul>
          </p>
        </div>
      </div>
    </div>
    """
  end
end
