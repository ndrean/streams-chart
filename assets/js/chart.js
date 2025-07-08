import { createChart, LineSeries } from "lightweight-charts";

const config = {
  width: 400,
  height: 300,
  timeScale: {
    timeVisible: true,
    secondsVisible: true,
  },
  priceScale: {
    position: "left",
    autoScale: true,
  },
  rightPriceScale: {
    visible: true,
  },
  leftPriceScale: {
    visible: true,
  },
  layout: {
    textColor: "black",
    background: { type: "solid", color: "white" },
  },
  crosshair: {
    mode: 0, // CrosshairMode.Normal
  },
};

export const Chart = {
  mounted() {
    const chart = createChart(this.el, config);

    chart.timeScale().applyOptions({
      borderColor: "#71649C",
    });

    chart.timeScale().fitContent();

    const btc = chart.addSeries(LineSeries, { priceScaleId: "right" });

    window.addEventListener("phx:update_chart", ({ detail }) => {
      btc.update({
        time: Math.round(new Date().getTime() / 1000),
        value: detail.col_b,
      });
    });
  },
};
