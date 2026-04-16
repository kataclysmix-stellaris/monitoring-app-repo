async function loadData() {
    const result = await fetch('/data_string.json');
    if (!result.ok) throw new Error(`Failed to load: ${result.status}`);
    const data = await result.json();
    return data;
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
function parseDateTime(date_log, time_log) {
    // --- DATE ---
    let [month, day, year] = date_log.split('/');
    year = Number(year) < 50 ? `20${year}` : `19${year}`;

    // --- TIME ---
    let [time, modifier] = time_log.split(' ');
    time = time.replace('.', ':');

    let [hours, minutes, seconds] = time.split(':');

    hours = Number(hours);

    if (modifier === 'PM' && hours !== 12) {
        hours += 12;
    }
    if (modifier === 'AM' && hours === 12) {
        hours = 0;
    }

    // --- BUILD DATE ---
    return new Date(
        Number(year),
        Number(month) - 1, // JS months are 0-based
        Number(day),
        hours,
        Number(minutes),
        Number(seconds)
    );
}
async function updateTime() {
    const data = await loadData();
    const now = new Date();

    const dateOptions = {
        year: 'numeric',   // 2026
        month: 'long',     // month
        day: 'numeric'     // day
    };

    const timeOptions = {
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: true
    };

    // Log Date and Time
    const logDT = parseDateTime(data.date_log, data.time_log);

    //Show Log Date
    document.getElementById('logDay').textContent =
        logDT.toLocaleDateString('en-US', dateOptions);

    //Show Log Time
    document.getElementById('logTime').textContent =
        logDT.toLocaleTimeString('en-US', timeOptions);

    //Show Current Date
    document.getElementById('today').textContent =
        now.toLocaleDateString('en-US', dateOptions);

    //Show Current Time
    document.getElementById('timeNow').textContent =
        now.toLocaleTimeString('en-US', timeOptions);
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
    updateTime();

    // Update every 5 seconds
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

    // Updates clock every half-second
    setInterval(async () => {
        updateTime();
    }, 500)
}

initCharts();