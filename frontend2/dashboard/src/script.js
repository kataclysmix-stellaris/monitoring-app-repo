async function loadData() {
    const r = await fetch('/data_string.json');
    if (!r.ok) throw new Error(`Failed to load: ${r.status}`);
    const d = await r.json();
    return d;
}
async function initCharts() {
    const data = await loadData();
    Chart.defaults.color = 'white';

    const cpuCtx = document.getElementById('cpuChart');
    const cpuChart = new Chart(cpuCtx, {
        type: 'bar',
        data: {
            labels: Array.from({ length: 16 }, (_, i) => `Core ${i+1}`),
            datasets: [{
                label: `CPU Usage per Core (%)`,
                data: data.cpu_per_core,
                borderColor: 'rgb(34, 104, 150)',
                backgroundColor: 'rgba(54, 162, 235, 0.85)',
                borderWidth: '5px',
                borderSkipped: 'bottom',
                fill: true
            }]
        },
        options: {
                animation: false,
                scales: {
                        y: { beginAtZero: true, max: 100 },
                        x: { ticks: {autoSkip: false, } }
                }
            }
        }
    );

    // Storage Chart (Pie)
    const storageCtx = document.getElementById('storageChart');
    const storageChart = new Chart(storageCtx, {
        type: 'pie',
        data: {
            labels: ['Used Storage', 'Free Storage'],
            datasets: [{
                label: 'Storage (%)',
                data: [data.disk_percent, 100 - data.disk_percent],
                backgroundColor: ['#FF6384', '#36A2EB'] // red = used, blue = free
            }]
        },
        options: {
            animation: false,
            responsive: true
        }
    });

    const ramCtx = document.getElementById('ramChart');
    const ramChart = new Chart(ramCtx, {
        type: 'pie', // pie chart
        data: {
            labels: ['Used RAM', 'Free RAM'],
            datasets: [{
                label: 'RAM Usage (%)',
                data: [data.ram_percent, 100 - data.ram_percent],
                backgroundColor: ['#FF6384', '#36A2EB'] // red = used, blue = free
            }]
        },
        options: {
            animation: false,
            responsive: true,
        }
    });

    // Update every 30 seconds
    setInterval(async () => {
        const data = await loadData(); // one fetch
        cpuChart.data.datasets[0].data = data.cpu_per_core;
        storageChart.data.datasets[0].data = [data.disk_percent, 100 - data.disk_percent];
        ramChart.data.datasets[0].data = [data.ram_percent, 100 - data.ram_percent];
        cpuChart.update();
        storageChart.update();
        ramChart.update();
    }, 30000);
}

initCharts();