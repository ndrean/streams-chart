defmodule ExStreamsWeb.BinanceLive do
  use ExStreamsWeb, :live_view
  alias ExStreams.{Mavg, BinanceClient}
  alias ExStreamsWeb.{Squiggly, Svg}

  @binance "binance"
  @mavg "m_avg"
  @period 5000
  @avg_chart_len 100

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(:pubsub, @binance)
      Phoenix.PubSub.subscribe(:pubsub, @mavg)
    end

    DynamicSupervisor.start_child(
      DynSup,
      {Mavg, [topic: @binance, period: @period, binance_stream: @binance, send_topic: @mavg]}
    )

    init_socket =
      socket
      |> assign(:env, Application.fetch_env!(:ex_streams, :env))
      |> assign(:is_streaming, false)
      |> assign(:title, "Binance")
      |> assign(:current_average, nil)
      |> assign(:mavg_pid, Process.whereis(ExStreams.Mavg))
      |> assign(:binance_pid, nil)
      |> assign(:chart, nil)
      |> assign(:chart_data, [])
      |> assign(:start_time, nil)
      |> assign(:avg_chart_len, @avg_chart_len)
      |> assign(:period, @period)
      |> assign(:period_change, 0)
      |> assign(:trend, 0)
      |> assign(:value, nil)
      |> assign(:nb_points, 0)
      |> assign(:mavg_start, false)
      |> stream(:data, [])

    {:ok, init_socket}
  end

  @impl true
  def handle_event("start_stream", _params, socket) do
    {:ok, binance_pid} =
      DynamicSupervisor.start_child(
        DynSup,
        {BinanceClient, [url: Application.get_env(:ex_streams, :streamer_url), topic: @binance]}
      )

    send(socket.assigns.mavg_pid, :resume)

    new_socket =
      socket
      |> assign(:binance_pid, binance_pid)
      |> assign(:is_streaming, true)
      |> assign(:mavg_start, true)
      |> assign(:start_time, DateTime.utc_now())

    {:noreply, new_socket}
  end

  def handle_event("stop_stream", _params, socket) do
    Logger.info("[BinanceLive] Stopping stream")
    GenServer.stop(socket.assigns.binance_pid, :normal)
    # :ok = DynamicSupervisor.terminate_child(DynSup, socket.assigns.binance_pid)
    send(socket.assigns.mavg_pid, :halt)

    new_socket =
      socket
      |> assign(:binance_pid, nil)
      |> assign(:is_streaming, false)
      |> assign(:mavg_start, false)

    # |> assign(:start_time, nil)

    {:noreply, new_socket}
  end

  def handle_event("clear_data", _params, socket) do
    Mavg.clear()

    new_socket =
      socket
      |> assign(:chart, nil)
      |> assign(:chart_data, [])
      |> assign(:nb_points, 0)
      |> assign(:value, nil)
      |> assign(:trend, 0)
      |> assign(:period_change, 0)
      |> assign(:current_average, nil)
      |> assign(:mavg_start, false)
      |> assign(:is_streaming, false)
      |> assign(:binance_pid, nil)
      |> assign(:start_time, nil)
      |> stream(:data, [], reset: true)

    {:noreply, new_socket}
  end

  @impl true
  def handle_info({:new_data, data, instant_change}, socket) do
    {:noreply,
     socket
     |> assign(:trend, instant_change)
     |> assign(:value, data.p)
     |> stream_insert(:data, data, at: 0)}
  end

  def handle_info({:new_average_point, new_point, nb_points}, socket) do
    current_chart_data = socket.assigns.chart_data
    last_avg = socket.assigns.current_average || 0
    %{col_a: t, col_b: m_avg} = new_point

    new_time = DateTime.from_unix!(t, :microsecond)

    new_chart_data =
      (current_chart_data ++
         [%{col_a: new_time, col_b: m_avg}])
      |> Enum.take(-@avg_chart_len)

    start_time = new_chart_data |> List.first() |> Map.get(:col_a)

    step = 0.005

    period_change =
      if last_avg == 0 do
        0
      else
        Float.round((m_avg - last_avg) / last_avg * 1_000_000, 3)
        |> case do
          v when v > step -> 1
          v when v < -step -> -1
          _ -> 0
        end
      end

    dataset = Contex.Dataset.new(new_chart_data)
    {min, max} = Contex.Dataset.column_extents(dataset, :col_b)

    plot =
      Contex.LinePlot.new(
        dataset,
        mapping: %{x_col: :col_a, y_cols: [:col_b]},
        custom_x_scale:
          Contex.TimeScale.new()
          |> Contex.TimeScale.domain(
            socket.assigns.start_time,
            new_time
          ),
        custom_y_scale:
          Contex.ContinuousLinearScale.new()
          |> Contex.ContinuousLinearScale.domain(min * 0.9995, max * 1.0005)
          |> Contex.Scale.set_range(0, 300),
        custom_x_formatter: fn _value -> "" end
      )

    new_svg =
      Contex.Plot.new(400, 300, plot)
      |> Contex.Plot.to_svg()

    new_socket =
      socket
      |> assign(:chart, new_svg)
      |> assign(:chart_data, new_chart_data)
      |> assign(:current_average, m_avg)
      |> assign(:period_change, period_change)
      |> assign(:nb_points, nb_points)
      |> assign(:start_time, start_time)
      |> push_event("update_chart", %{col_b: m_avg})

    {:noreply, new_socket}
  end
end
