defmodule ExStreamsWeb.Svg do
  use Phoenix.Component
  alias ExStreamsWeb.Squiggly

  attr :chart, :string, required: true
  attr :period, :integer, default: 100
  attr :nb_points, :integer, default: 20
  attr :change, :integer, default: 0

  def display(assigns) do
    ~H"""
    <div class="bg-white p-6 rounded-lg shadow-lg border">
      <h3 class="text-lg font-semibold text-gray-800 mb-4">
        BTCUSD (Last {@nb_points} of averages on {@period / 1000}s )
      </h3>

      <span class="flex">Trend: &nbsp<Squiggly.display change1={@change} color={@change} /></span>

      <div class="chart-container">
        {@chart}
      </div>
    </div>
    """
  end
end

defmodule ExStreamsWeb.Squiggly do
  use Phoenix.Component

  defp color(1), do: "text-green-500"
  defp color(-1), do: "text-red-500"
  defp color(0), do: "text-gray-500"

  defp d(1), do: "M13 7h8m0 0v8m0-8l-8 8-4-4-6 6"
  defp d(-1), do: "M13 17h8m0 0v-8m0 8l-8-8-4 4-6-6"
  defp d(0), do: "M13 12h8m0 0v0m0 0l-8 0-4 0-6 0"

  attr :change1, :integer, default: 0
  attr :color, :integer, default: 0

  def display(assigns) do
    ~H"""
    <svg class={["w-6 h-6", color(@color)]} fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d={d(@change1)}></path>
    </svg>
    """
  end
end
