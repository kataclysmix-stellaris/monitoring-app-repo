async function loadData() {
    const r = await fetch('/data_string.json');
    if (!r.ok) throw new Error(`Failed to load: ${r.status}`);
    const d = await r.json();
    return d;
}
function getNodeStatus(data) {
    if (data.cpu_percent > 90 || data.ram_percent > 90 || data.disk_percent > 90) {
        document.getElementById("nodeStatus").style.color = "red";
        return 'Critical';
    } else if (data.cpu_percent > 70 || data.ram_percent > 70 || data.disk_percent > 70) {
        document.getElementById("nodeStatus").style.color = "yellow";
        return 'Warning';
    } else {
        document.getElementById("nodeStatus").style.color = "green";
        return 'OK';
    }
}
const nandType = document.getElementById('nandType');
const nandChannel = document.getElementById('nandChannel');
function updateNAND(data) {
    nandType.textContent = data.nand?.type ?? 'Pending...';
    nandChannel.textContent = data.nand?.channel ?? 'Pending...';
}
const cpuTempSpan = document.getElementById('cpuTemp');
const systemTempSpan = document.getElementById('sysTemp');
function updateTemperature(data) {
    cpuTempSpan.textContent = data.cpu_temp !== null ? `${data.cpu_temp}°F` : 'N/A';
    systemTempSpan.textContent = data.system_temp !== null ? `${data.system_temp}°F` : 'N/A';
    
    // CPU temp color
    if (data.cpu_temp !== null) {
        cpuTempSpan.style.color = data.cpu_temp > 80 ? 'orange' : 'blue';
    }

    // System temp color
    if (data.system_temp !== null) {
        systemTempSpan.style.color = data.system_temp > 80 ? 'orange' : 'blue';
    }
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
                borderWidth: '5px',
                borderColor: 'rgb(34, 104, 150)',
                backgroundColor: 'rgba(54, 162, 235, 0.85)',
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

    document.getElementById('nodeStatus').textContent = `${getNodeStatus(data)}`;
    updateTemperature(data);
    updateNAND(data);

    // Update every 30 seconds
    setInterval(async () => {
        const data = await loadData(); // one fetch
        cpuChart.data.datasets[0].data = data.cpu_per_core;
        storageChart.data.datasets[0].data = [data.disk_percent, 100 - data.disk_percent];
        ramChart.data.datasets[0].data = [data.ram_percent, 100 - data.ram_percent];
        document.getElementById('nodeStatus').textContent = `${getNodeStatus(data)}`;
        updateNAND(data);
        updateTemperature(data);
        cpuChart.update();
        storageChart.update();
        ramChart.update();
    }, 5000);
}

initCharts();