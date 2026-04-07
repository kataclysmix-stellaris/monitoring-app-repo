// Removed invalid import; if you need to load JSON at runtime, use fetch:
// fetch('/path/to/data_string.json').then(r => r.json()).then(d => { /* use d */ });

const data = {

    cpu_percent: 0.3,

    cpu_core_percent: [
        1.0,
        93.0,
        23.0,
        54.0,
        70.0,
        19.0,
        70.0,
        67.0
    ],

    ram_percent: 80.7,

    disk_percent: 4.01,

    cpu_temp: 28.0,
    
    system_temp: 28.0,
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