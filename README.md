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
- CSR rendered chart in Canvas with `lightweight-charts` of the moving average. Only the last tuple `[time, value]` is sent. 150.65 kB
- CSR rendered chart in Canvas with `uPlot` of the moving average. Only the last tuple `[time, value]` is sent.  52.69 kB uncompressed.

> Note: app.js is 124.12 kB uncompressed.

## Example


<img width="350" height="573" alt="Screenshot 2025-07-10 at 13 11 09" src="https://github.com/user-attachments/assets/6391dec1-9abd-4c52-87a2-175462c3b9b4" />
