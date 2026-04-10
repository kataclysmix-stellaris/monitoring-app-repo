let formMode = 'register';

const registerForm = document.getElementById('registerForm');
registerForm?.addEventListener('submit', submitForm);

const registerMessage = document.getElementById('registerFormMessage');

function showMessage(element, message, type) {
    element.textContent = message;
    element.classList.remove('opacity-0');
    element.classList.add('opacity-100');
    element.classList.add('translate-y-2');

    element.classList.remove('text-red-400', 'text-green-400');

    if (type === 'error') {
        element.classList.add('text-red-400');
    }
    else {
        element.classList.add('text-green-400');
    }

    if (element._timeout) clearTimeout(element._timeout);

    element._timeout = setTimeout(() => {
        element.classList.add('opacity-0');
        element.classList.remove('opacity-100');
        element.classList.remove('translate-y-2');
    }, 3000);
}

const moveToRegister = document.getElementById('moveToRegister');
const moveToLogin = document.getElementById('moveToLogin');
const forgotpasswordLink = document.getElementById('forgotPassword');
const emailInputContainer = document.getElementById('emailInputContainer');

moveToRegister?.addEventListener('click',() => {moveToButtonClick('register')});
moveToLogin?.addEventListener('click',() => {moveToButtonClick('login')});

function moveToButtonClick (moveTo) {
    if (moveTo !== 'register' && moveTo !== 'login') return;
    formMode = moveTo;
    registerForm.reset();

    if (moveTo === 'register') {
        moveToLogin.classList.add('opacity-50');
        moveToLogin.classList.remove('scale-105');
        moveToRegister.classList.add('scale-105');
        moveToRegister.classList.remove('opacity-50');
        forgotpasswordLink.classList.add('hidden');
        emailInputContainer.classList.remove('hidden');
    }
    else {
        moveToLogin.classList.add('scale-105');
        moveToLogin.classList.remove('opacity-50');
        moveToRegister.classList.add('opacity-50');
        moveToRegister.classList.remove('scale-105');
        forgotpasswordLink.classList.remove('hidden');
        emailInputContainer.classList.add('hidden');
    }
}

function submitForm(event) {
    event.preventDefault();

    const username = document.getElementById("usernameInput")?.value;
    const password = document.getElementById("passwordInput")?.value;
    const email = document.getElementById("emailInput")?.value;
    
    try {
        if (formMode === 'register') {
            registerUser(username, password, email);
        }
        else {
            loginUser(username, password);
        }
    }
    catch (err) {
        showMessage(registerMessage, err.message, "error");
    }
    
}

function registerUser(username, password, email) {
    if (!username || !password || !email) {
        showMessage(registerMessage, "All fields are required", "error");
        return;
    }
    
    const users = JSON.parse(localStorage.getItem("users")) || [];
    
    if (users.find(user => user.username === username)) {
        showMessage(registerMessage, "Username already exists", "error");
        return;
    }

    if (users.find(user => user.email === email)) {
        showMessage(registerMessage, "Email already exists", "error");
        return;
    }
    
    if (username.includes(' ') || password.includes(' ') || email.includes(' ')) {
        showMessage(registerMessage, "Inputs cannot contain spaces", "error");
        return;
    }
    
    if (password.length < 8) {
        showMessage(registerMessage, "Password must be at least 8 or more characters", "error");
        return;
    }

    showMessage(registerMessage, "Registration successful", "success");
    localStorage.setItem("users", JSON.stringify([...users, { username, password, email }]));
    
}

function loginUser(username,password) {
    if (!username || !password) {
        showMessage(registerMessage, "All fields are required", "error");
        return;
    }
    
    const users = JSON.parse(localStorage.getItem("users")) || [];
    const user = users.find(user => user.username === username);
    
    if (!user) {
        showMessage(registerMessage, "User does not exist", "error");
        return;
    }
    
    if (user.password !== password) {
        showMessage(registerMessage, "Incorrect password", "error");
        return;
    }

    showMessage(registerMessage, "Login successful", "success");
    localStorage.setItem("loggedInUser", JSON.stringify(user));
}