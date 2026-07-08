const app = document.getElementById('app');
const panelTitle = document.getElementById('panel-title');
const footerText = document.getElementById('footer-text');
const messageBox = document.getElementById('message-box');
const loginForm = document.getElementById('login-form');
const registerForm = document.getElementById('register-form');
const rememberCheckbox = document.getElementById('login-remember');
const loginUsernameInput = document.getElementById('login-username');
const loginPasswordInput = document.getElementById('login-password');

const REMEMBER_KEY = 'nb_accounts_remember';

function loadRememberedCredentials() {
    try {
        const raw = localStorage.getItem(REMEMBER_KEY);
        if (!raw) return;
        const saved = JSON.parse(raw);
        if (saved && saved.username) {
            loginUsernameInput.value = saved.username;
            loginPasswordInput.value = saved.password || '';
            rememberCheckbox.checked = true;
        }
    } catch (e) {
        // rossz/sérült mentett adat - egyszerűen figyelmen kívül hagyjuk
    }
}

function saveRememberedCredentials(username, password) {
    try {
        localStorage.setItem(REMEMBER_KEY, JSON.stringify({ username, password }));
    } catch (e) {}
}

function clearRememberedCredentials() {
    try {
        localStorage.removeItem(REMEMBER_KEY);
    } catch (e) {}
}

function getResourceName() {
    return (typeof GetParentResourceName === 'function') ? GetParentResourceName() : (window.location.hostname || 'nb_accounts');
}

function showMessage(text, type) {
    messageBox.textContent = text;
    messageBox.className = `message ${type}`;
}

function clearMessage() {
    messageBox.className = 'message hidden';
    messageBox.textContent = '';
}

const ACCOUNT_RULES = {
    minUsernameLength: 3,
    maxUsernameLength: 20,
    minPasswordLength: 6
};

function setMode(mode) {
    clearMessage();
    if (mode === 'login') {
        panelTitle.textContent = 'BEJELENTKEZÉS';
        footerText.textContent = 'Vortex Military // Belépési terminál';
        loginForm.classList.remove('hidden');
        registerForm.classList.add('hidden');
    } else {
        panelTitle.textContent = 'REGISZTRÁCIÓ';
        footerText.textContent = 'Vortex Military // Új fiók létrehozása';
        registerForm.classList.remove('hidden');
        loginForm.classList.add('hidden');
    }
}

window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'open':
            app.classList.remove('hidden');
            setMode(data.mode);
            if (data.mode === 'login') {
                loadRememberedCredentials();
            }
            // Visszaigazoljuk a Lua kliensnek, hogy megkaptuk és megjelenítettük.
            // Ha ez nem érne célba valamiért, a Lua oldal akkor is folytatja a
            // próbálkozást néhányszor, szóval ez csak optimalizáció (korábbi leállás).
            fetch(`https://${getResourceName()}/uiOpened`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({})
            }).catch(() => {});
            break;

        case 'close':
            app.classList.add('hidden');
            break;

        case 'loginResult':
            if (!data.success) {
                showMessage(data.message || 'Hiba történt.', 'error');
            }
            break;

        case 'registerResult':
            if (!data.success) {
                showMessage(data.message || 'Hiba történt.', 'error');
            }
            break;
    }
});

loginForm.addEventListener('submit', (e) => {
    e.preventDefault();
    clearMessage();

    const username = document.getElementById('login-username').value.trim();
    const password = document.getElementById('login-password').value;

    if (!username || !password) {
        showMessage('Töltsd ki az összes mezőt.', 'error');
        return;
    }

    if (rememberCheckbox.checked) {
        saveRememberedCredentials(username, password);
    } else {
        clearRememberedCredentials();
    }

    fetch(`https://${getResourceName()}/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ username, password })
    });
});

registerForm.addEventListener('submit', (e) => {
    e.preventDefault();
    clearMessage();

    const username = document.getElementById('register-username').value.trim();
    const email = document.getElementById('register-email').value.trim();
    const password = document.getElementById('register-password').value;
    const passwordConfirm = document.getElementById('register-password-confirm').value;

    if (!username || !email || !password || !passwordConfirm) {
        showMessage('Töltsd ki az összes mezőt.', 'error');
        return;
    }

    if (username.length < ACCOUNT_RULES.minUsernameLength || username.length > ACCOUNT_RULES.maxUsernameLength) {
        showMessage(`A felhasználónév ${ACCOUNT_RULES.minUsernameLength}-${ACCOUNT_RULES.maxUsernameLength} karakter hosszú lehet.`, 'error');
        return;
    }

    const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailPattern.test(email)) {
        showMessage('Érvénytelen email cím.', 'error');
        return;
    }

    if (password.length < ACCOUNT_RULES.minPasswordLength) {
        showMessage(`A jelszó legalább ${ACCOUNT_RULES.minPasswordLength} karakter legyen.`, 'error');
        return;
    }

    if (password !== passwordConfirm) {
        showMessage('A két jelszó nem egyezik.', 'error');
        return;
    }

    fetch(`https://${getResourceName()}/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify({ username, email, password })
    });
});

// ESC letiltása, hogy ne lehessen kilépni a login/regisztráció alól
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        e.preventDefault();
    }
});
