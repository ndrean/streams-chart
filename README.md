# ExStreams

Receive streams from Binance endpoint with `Websockex`.

Start/stop the WebSockex GenServer on-the-fly.

Start the "moving-average" GenServer calculator on mount.

Render:
- statistics:
  - instant price via `@streams`
  - moving average over 5s
  - trend with dynamic SVG
- SSR rendered SVG chart with `contEx` of the moving average. The whole SVg is send over the LiveSocket but LiveView renderes only the changes
- CSR rendered chart in Canvas with `lightweight-charts` of the moving average. Only the last tuple `[time, value]` is sent.
- [TODO] CSR with `uPlot`
  
## Example

<img width="607" alt="Screenshot 2025-07-08 at 10 01 13" src="https://github.com/user-attachments/assets/b89cd919-d235-4471-b6af-ff2a832418a8" />
