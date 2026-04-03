// Removed invalid import; if you need to load JSON at runtime, use fetch:
// fetch('/path/to/data_string.json').then(r => r.json()).then(d => { /* use d */ });

const data = {
    cpu_percent: 10.4,
    cpu_core_percent: [23.4, 6.2, 17.5, 3.2, 35.8, 3.1, 35.9, 6.2,
        26.2, 3.1, 20.3, 1.6, 6.2, 4.7, 4.7, 3.1],
    ram_used: 10.083610534667969,
    ram_percent: 31.9,
    disk_percent: 35.3
};

const ctx = document.getElementById('cpuChart');

const cpuChart = new Chart(ctx, {
    type: 'line',
    data: {
        labels: Array.from({ length: 16 }, (_, i) => `Core ${i}`),
        datasets: [{
            label: 'CPU % per Core',
            data: data.cpu_core_percent,
            borderColor: 'blue',
            backgroundColor: 'rgba(0, 0, 255, 0.1)',
            fill: true
        }]
    },
    options: {
        animation: false,
        scales: {
            y: { beginAtZero: true, max: 100 }
        }
    }
});

// Optional: update every minute if your JSON changes
setInterval(() => {
    cpuChart.data.datasets[0].data = data.cpu_core_percent;
    cpuChart.update();
}, 30000);

// Storage Chart (Pie)
const storageCtx = document.getElementById('storageChart');
const storageChart = new Chart(storageCtx, {
    type: 'pie',
    data: {
        labels: ['Used', 'Free'],
        datasets: [{
            data: [data.disk_percent, 100 - data.disk_percent],
            backgroundColor: ['#FF6384', '#36A2EB'] // red = used, blue = free
        }]
    },
    options: {
        animation: false,
        responsive: true
    }
});

// Update every 30 seconds
setInterval(() => {
    storageChart.data.datasets[0].data = [data.disk_percent, 100 - data.disk_percent];
    storageChart.update();
}, 30000);

const ramCtx = document.getElementById('ramChart');
const ramChart = new Chart(ramCtx, {
    type: 'bar', // vertical bar chart
    data: {
        labels: ['Used RAM', 'Free RAM'],
        datasets: [{
            label: 'RAM Usage (%)',
            data: [data.ram_used, 100 - data.ram_percent],
            backgroundColor: ['#FF6384', '#36A2EB'] // red = used, blue = free
        }]
    },
    options: {
        animation: false,
        responsive: true,
        scales: {
            y: { beginAtZero: true, max: 100 }
        }
    }
});

// Update every 30 seconds
setInterval(() => {
    ramChart.data.datasets[0].data = [data.ram_percent, 100 - data.ram_percent];
    ramChart.update();
}, 30000);