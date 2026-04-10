// Chart options using ApexCharts (Flowbite style)
const options = {
  chart: {
    type: "line",
    height: 300,
    toolbar: { show: false }
  },
  series: [
    {
      name: "CPU Usage (%)",
      data: [12, 30, 25, 40, 35, 50, 45] // Example data
    }
  ],
  xaxis: {
    categories: ["10:00", "10:15", "10:30", "10:45", "11:00", "11:15", "11:30"]
  },
  stroke: { curve: "smooth" },
  colors: ["#3b82f6"], // Tailwind blue
  grid: { borderColor: "#444" },
  theme: {
    mode: "dark" // matches your dashboard style
  }
};

// Render the chart
const loadChart = new ApexCharts(
  document.querySelector("#system-load-chart"),
  options
);
loadChart.render();