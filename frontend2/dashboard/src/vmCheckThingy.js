// Random stuff that is needed
async function loadData() {
    const result = await fetch('/data_string.json');
    if (!result.ok) throw new Error(`Failed to load: ${result.status}`);
    const data = await result.json();
    return data;
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
const elements = document.getElementsByClassName("vmObject");
function notWorky(data) {
    const nodeStatus = getNodeStatus(data);
    for (let el of elements) {
        if (nodeStatus === 'Critical') {
            el.style.color = "var(--color-red-400)";
        }
        else if (nodeStatus === 'Warning') {
            el.style.color = "var(--color-yellow-400)";
        }
        else {
            el.style.color = "var(--color-lime-400)";
        }
    }
}
notWorky(loadData());