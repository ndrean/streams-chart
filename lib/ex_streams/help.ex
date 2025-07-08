defmodule Help do
  def binance do
    DynamicSupervisor.which_children(DynSup)
    |> Enum.filter(fn {_, _pid, :worker, [name]} -> name == ExStreams.BinanceClient end)
  end

  def mavg do
    :sys.get_state(ExStreams.Mavg)
  end
end
