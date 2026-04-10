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

moveToRegister?.addEventListener('click',() => {moveToButtonClick('register')});
moveToLogin?.addEventListener('click',() => {moveToButtonClick('login')});

function moveToButtonClick (moveTo) {
    if (moveTo !== 'register' && moveTo !== 'login') return;
    formMode = moveTo;
    registerForm.reset();

    if (moveTo === 'register') {
        moveToLogin.classList.add('opacity-50');
        moveToRegister.classList.add('scale-105');
        moveToRegister.classList.remove('opacity-50');
        moveToLogin.classList.remove('scale-105');
        forgotpasswordLink.classList.add('hidden');
    }
    else {
        moveToRegister.classList.add('opacity-50');
        moveToLogin.classList.add('scale-105');
        moveToLogin.classList.remove('opacity-50');
        moveToRegister.classList.remove('scale-105');
        forgotpasswordLink.classList.remove('hidden');
    }
}

function submitForm(event) {
    event.preventDefault();
    
    const username = document.getElementById("usernameInput")?.value;
    const password = document.getElementById("passwordInput")?.value;

    if (!username || !password) {
        alert("username and password are required");
        return;
    }

    if (username.includes(' ') || password.includes(' ')) {
        alert("username and password cannot contain spaces");
        return;
    }

    if (password.length < 8) {
        alert("password must be at least 8 or more characters");
        return;
    }

    const users = JSON.parse(localStorage.getItem("users")) || [];

    const user = users.find(user => user.username === username);

    if (!user) {
        alert("user does not exist");
        return;
    }

    if (user.password !== password) {
        alert("incorrect password");
        return;
    }
}
