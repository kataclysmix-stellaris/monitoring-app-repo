async function loadData() {
    const result = await fetch('/data_string.json');
    if (!result.ok) throw new Error(`Failed to load: ${result.status}`);
    const data = await result.json();
    return data;
}

function tempDoesWorky() {
    document.addEventListener("DOMContentLoaded", () => {
        const tempCheck = document.getElementById("tempCheck");
        const tempUnits = document.getElementById("tempUnits");

        if (!tempCheck || !tempUnits) {
            console.log("Temperature controls not found in DOM");
            return;
        }
    });
}

function getNodeStatus(data) {
    if (data.cpu_percent > 90 || data.ram_percent > 90 || data.disk_percent > 90) {
        document.getElementById("nodeStatus").style.color = "var(--color-red-400)";
        return 'Critical';
    } else if (data.cpu_percent > 70 || data.ram_percent > 70 || data.disk_percent > 70) {
        document.getElementById("nodeStatus").style.color = "var(--color-yellow-400)";
        return 'Warning';
    } else {
        document.getElementById("nodeStatus").style.color = "var(--color-lime-400)";
        return 'OK'; 
    }
}

const cpuTempSpan = document.getElementById('cpuTemp');
const systemTempSpan = document.getElementById('sysTemp');

function toCelsius(fahrenheit) {
    return (fahrenheit - 32) * 5 / 9;
}

let tempUnit = 'f'; // default to Fahrenheit
const tempToggle = document.getElementsByName('unit');
tempToggle.forEach(radio => {
    radio.addEventListener('change', () => {
        tempUnit = radio.value;
    });
});

function formatTemp(value) {
  if (value === null) return 'N/A';

  if (tempUnit == 'c') {
    return `${toCelsius(value).toFixed(1)}°C`;
  }

  return `${value.toFixed(1)}°F`;
}

function updateTemperature(data) {
  cpuTempSpan.textContent = formatTemp(data.cpu_temp);
  systemTempSpan.textContent = formatTemp(data.system_temp);

  updateColor(cpuTempSpan, data.cpu_temp);
  updateColor(systemTempSpan, data.system_temp);
}

function updateColor(el, value) {
  if (value === null) return;

  el.style.color =
    value > 80
      ? 'var(--color-orange-400)'
      : 'var(--color-blue-400)';
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
    updateTime();

    // Update every 5 seconds
    setInterval(async () => {
        const data = await loadData(); // one fetch
        cpuChart.data.datasets[0].data = data.cpu_per_core;
        storageChart.data.datasets[0].data = [data.disk_percent, 100 - data.disk_percent];
        ramChart.data.datasets[0].data = [data.ram_percent, 100 - data.ram_percent];
        document.getElementById('nodeStatus').textContent = `${getNodeStatus(data)}`;
        cpuChart.update();
        storageChart.update();
        ramChart.update();
    }, 5000);

    // Updates clock every half-second
    setInterval(async () => {
        updateTime();
        updateTemperature(data);
    }, 500)
}

function checkBoxes() {
    // Display elements
    const cpuDisplay = document.getElementById('cpuDisplay');
    const ramDisplay = document.getElementById('ramDisplay');
    const storageDisplay = document.getElementById('storageDisplay');
    const tempDisplay = document.getElementById('tempDisplay');
    const tempUnits = document.getElementById('tempUnits');
    const logsDisplay = document.getElementById('logsDisplay');
    const nodeStatusDisplay = document.getElementById('nodeStatusDisplay');
    // Checkboxes
    const cpuCheck = document.getElementById('cpuCheck');
    const ramCheck = document.getElementById('ramCheck');
    const storageCheck = document.getElementById('storageCheck');
    const tempCheck = document.getElementById('tempCheck');
    const logsCheck = document.getElementById('logsCheck');
    const nodeStatusCheck = document.getElementById('nodeStatusCheck');
    // Event listeners for checkboxes
    cpuCheck.addEventListener('change', () => {
        cpuDisplay.classList.toggle('nodisplay', !cpuCheck.checked);
    });

    ramCheck.addEventListener('change', () => {
        ramDisplay.classList.toggle('nodisplay', !ramCheck.checked);
    });

    storageCheck.addEventListener('change', () => {
        storageDisplay.classList.toggle('nodisplay', !storageCheck.checked);
    });

    tempCheck.addEventListener('change', () => {
        tempDisplay.classList.toggle('nodisplay', !tempCheck.checked);
        tempUnits.style.display = tempCheck.checked ? 'block' : 'none';
    });

    logsCheck.addEventListener('change', () => {
        logsDisplay.classList.toggle('nodisplay', !logsCheck.checked);
    });

    nodeStatusCheck.addEventListener('change', () => {
        nodeStatusDisplay.classList.toggle('nodisplay', !nodeStatusCheck.checked);
    });

}

initCharts();
tempDoesWorky();
checkBoxes();

const IP = 'https://unrevised-immunize-reapply.ngrok-free.dev';
const logoutButton = document.getElementById('logout_button');
logoutButton?.addEventListener('click', async () => {
    try {
        const response = await fetch(`${IP}/api/logout`, { 
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            credentials: 'include'
         });
    
         if (!response.ok) {
            throw new Error('Logout Failed');
         }
        localStorage.removeItem('loggedInUser');
        window.location.href = 'login.html';
    }
    catch (error) {
        console.error(error);
    }
});
const userSpan = document.getElementById('user');
const loggedInUser = JSON.parse(localStorage.getItem('loggedInUser'));
if (userSpan) userSpan.textContent = loggedInUser || 'Userssss';