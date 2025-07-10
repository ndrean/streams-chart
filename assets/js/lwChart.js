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

export const LWChart = {
  mounted() {
    const chart = createChart(this.el, config);

    chart.timeScale().applyOptions({
      borderColor: "#71649C",
    });

    chart.timeScale().fitContent();

    const btc = chart.addSeries(LineSeries, { priceScaleId: "right" });

    this.updateChart = ({ detail }) => {
      const time = Math.round(new Date().getTime() / 1000);
      const value = detail.col_b;

      // Update the chart with new data
      btc.update({
        time: time,
        value: value,
      });
    };

    window.addEventListener("phx:update_chart", this.updateChart);
    // this.handleEvent("update_chart", this.updateChart);
  },
  destroyed() {
    window.removeEventListener("phx:update_chart", this.updateChart);
  },
};
