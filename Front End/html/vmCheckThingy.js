// Random stuff that is needed
let nodeStatus = 0;

const elements = document.getElementsByClassName("vmObject");
// Goes below or above 0 if it has an error and resets back to 0 when the error is fixed.
function notWorky(x) {
    for (let el of elements) {
        if (x === 0) {
            el.style.color = "#00FF00";
            el.classList.remove("critical");
        } else {
            el.style.color = "";
            el.classList.add("critical");
        }
    }
}
notWorky(nodeStatus);