// Random stuff that is needed
let nodeStatus = 0;

const element = document.getElementsByClassName("vmObject");
// Goes below or above 0 if it has an error and resets back to 0 when the error is fixed.
function notWorky(x) {
    if (x != 0) {
        element.style.color = "#00FF00";
    } else {
        element.style.class = "critical"
    }
}

let i = 0;
for(i in element){
    notWorky(nodeStatus);
    i++;
}