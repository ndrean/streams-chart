import uPlot from "uplot";
import "uplot/dist/uPlot.min.css";

/*
async function loaduPlotCSS() {
  const css = await import("uplot/dist/uPlot.min.css");
  const style = document.createElement("style");
  style.setAttribute("id", "inline-uplot-css");
  style.textContent = css.default;
  document.head.appendChild(style);
}
  */

const opts = {
  width: 400,
  height: 300,
  series: [{}, { show: true, stroke: "red", width: 2 }],
};

export const UPChart = {
  mounted() {
    const buffer = 100; // Keep 30 data points
    this.data = [[], []];
    this.chart = new uPlot(opts, this.data, this.el);

    const update = () => {
      this.chart.setData(this.data);
    };

    this.handleEvent("update_chart", ({ col_b }) => {
      const time = Math.round(new Date().getTime() / 1000);
      const value = col_b;

      this.data = [
        [...this.data[0], time].slice(-buffer),
        [...this.data[1], value].slice(-buffer),
      ];

      update();
    });
  },

  destroyed() {
    this.chart.destroy();
  },
};
