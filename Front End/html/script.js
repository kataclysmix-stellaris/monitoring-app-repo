document.addEventListener("DOMContentLoaded", () => {
    console.log("DOM ready");

    const canvas = document.getElementById("cpuChart");
    console.log("canvas:", canvas);

    const ctx = canvas.getContext("2d");

    new Chart(ctx, {
        type: "line",
        data: {
            labels: ["2000","2001","2002","2003","2004","2005"],
            datasets: [{
                label: "CPU",
                data: [65,59,80,81,56,55]
            }]
        }
    });
});