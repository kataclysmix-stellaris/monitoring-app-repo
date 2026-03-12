// --- Login Page ---
function login() {
    const user = document.getElementById("username").value;
    const pass = document.getElementById("password").value;

    // Hardcoded user credentials
    if(user === "admin" && pass === "1234") {
        // Save user info in sessionStorage
        sessionStorage.setItem("loggedIn", "true");
        sessionStorage.setItem("username", user);
        // Redirect to dashboard
        window.location.href = "dashboard.html";
    } else {
        document.getElementById("error").innerText = "Invalid username or password.";
    }
}

// --- Dashboard Page ---
function initDashboard() {
    // Block access if not logged in
    if(sessionStorage.getItem("loggedIn") !== "true") {
        alert("You must log in first!");
        window.location.href = "index.html";
        return;
    }

    // Display username
    document.getElementById("user").innerText = sessionStorage.getItem("username");

    // Restrict edit button to logged-in users
    const editBtn = document.getElementById("editBtn");
    editBtn.addEventListener("click", () => {
        document.getElementById("message").innerText = "Dashboard edited successfully!";
    });
}

// --- Logout Function ---
function logout() {
    sessionStorage.clear();
    window.location.href = "index.html";
}

// --- Auto-run dashboard init ---
if(window.location.pathname.endsWith("dashboard.html")) {
    initDashboard();
}