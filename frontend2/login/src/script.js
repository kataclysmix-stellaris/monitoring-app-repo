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

moveToRegister?.addEventListener('click',() => {moveToButtonClick('register')});
moveToLogin?.addEventListener('click',() => {moveToButtonClick('login')});

function moveToButtonClick (moveTo) {
    if (moveTo !== 'register' && moveTo !== 'login') return;

    registerForm.reset();

    if (moveTo === 'register') {
        formMode = 'register';
        moveToLogin.classList.add('opacity-50');
        moveToRegister.classList.add('scale-105');
        moveToRegister.classList.remove('opacity-50');
        moveToLogin.classList.remove('scale-105');
    }
    else {
        formMode = 'login';
        moveToRegister.classList.add('opacity-50');
        moveToLogin.classList.add('scale-105');
        moveToLogin.classList.remove('opacity-50');
        moveToRegister.classList.remove('scale-105');
    }
}

function submitForm(event) {
    event.preventDefault();

}

// Password-Length = 8
// event.preventDefault();
// .includes(' ')
// return 

// Password must be 8 character long or more 
// Password & username must not contain spaces
// Password and username must be filled out
// Username doesnt already exist. 

// check if user even exists
// For login check if password matches the users password