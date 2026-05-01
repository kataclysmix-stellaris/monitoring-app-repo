let formMode = 'register';

const registerForm = document.getElementById('registerForm');
const forgotPasswordForm = document.getElementById('forgotPasswordForm');

registerForm?.addEventListener('submit', submitRegisterForm);
forgotPasswordForm?.addEventListener('submit', submitForgotPasswordForm);

const registerMessage = document.getElementById('registerFormMessage');
const forgotPasswordMessage = document.getElementById('forgotPasswordFormMessage');

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

function submitRegisterForm(event) {
    event.preventDefault();
    
    try {
        const username = document.getElementById("usernameInput")?.value;
        const password = document.getElementById("passwordInput")?.value;
        const email = document.getElementById("emailInput")?.value;
        
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

const IP = 'https://unrevised-immunize-reapply.ngrok-free.dev';

function registerUser(username, password, email) {
    if (!username || !password || !email) {
        showMessage(registerMessage, "All fields are required", "error");
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
    try {
        fetch(`${IP}/api/register/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({ username, password })
        });
    } catch (error) {
        showMessage(registerMessage, error.message, "error");
    } 
}

async function loginUser(username,password) {
    if (!username || !password) {
        showMessage(registerMessage, "All fields are required", "error");
        return;
    }

    try {
        const response = await fetch(`${IP}/api/login/`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            credentials: 'include',
            body: JSON.stringify({ username, password })
        });

        const data = await response.json();

        if (!response.ok) {
            throw new Error(data.detail || "Login failed");
        }


        showMessage(registerMessage, "Login successful", "success");
        localStorage.setItem("loggedInUser", JSON.stringify(data));
        window.location.href = './dashboard.html';
    } catch (error) {
        showMessage(registerMessage, error.message, "error");
    }
}

function submitForgotPasswordForm(event) {
    event.preventDefault();

    try {
        const email = document.getElementById("recoveryEmailInput")?.value;
        const password = document.getElementById("recoveryPasswordInput")?.value;
        const confirmPassword = document.getElementById("recoveryPasswordConfirmInput")?.value;
    
        if (!email || !password || !confirmPassword) {
            showMessage(forgotPasswordMessage, "All fields are required", "error");
            return;
        }
        
        const users = JSON.parse(localStorage.getItem("users")) || [];
    
        if (!users.find(user => user.email === email)) {
            showMessage(forgotPasswordMessage, "No account found with that email", "error");
            return;
        }
    
        if (password !== confirmPassword) {
            showMessage(forgotPasswordMessage, "Passwords do not match", "error");
            return;
        }
    
        if (email.includes(' ') || password.includes(' ') || confirmPassword.includes(' ')) {
            showMessage(forgotPasswordMessage, "Inputs cannot contain spaces", "error");
            return;
        }
        
        if (password.length < 8) {
            showMessage(forgotPasswordMessage, "Password must be at least 8 or more characters", "error");
            return;
        }

        showMessage(forgotPasswordMessage, "Email sent", "success");
    }
    catch (err) {
        showMessage(forgotPasswordMessage, err.message, "error");
    }
}
