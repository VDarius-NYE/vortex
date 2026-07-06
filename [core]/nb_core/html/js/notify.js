const container = document.getElementById('notify-container');

const ITEM_HEIGHT = 62;   // becsült magasság + gap a stackeléshez
const GAP = 10;

let activeNotifications = []; // { el } sorban, index 0 = legújabb (legfelül)

const ICONS = {
    success: 'OK',
    error: '!!',
    warning: '!',
    info: 'i'
};

function repositionAll() {
    activeNotifications.forEach((entry, index) => {
        entry.el.style.top = `${index * (ITEM_HEIGHT + GAP)}px`;
    });
}

function addNotification({ message, type = 'info', duration = 5000 }) {
    const validTypes = ['success', 'error', 'warning', 'info'];
    if (!validTypes.includes(type)) type = 'info';

    const el = document.createElement('div');
    el.className = `notify notify-${type}`;
    el.innerHTML = `
        <div class="notify-content">
            <div class="notify-icon">${ICONS[type]}</div>
            <div class="notify-text">${escapeHtml(message)}</div>
        </div>
        <div class="notify-bar"><div class="notify-bar-fill"></div></div>
    `;

    container.appendChild(el);

    const entry = { el };
    activeNotifications.unshift(entry); // legújabb legfelülre (index 0)
    repositionAll();

    // Belépő animáció + progress bar indítása
    requestAnimationFrame(() => {
        el.classList.add('show');

        const fill = el.querySelector('.notify-bar-fill');
        fill.style.transitionDuration = `${duration}ms`;

        requestAnimationFrame(() => {
            fill.style.width = '0%';
        });
    });

    // Automatikus eltávolítás a megadott idő után
    setTimeout(() => {
        removeNotification(entry);
    }, duration);
}

function removeNotification(entry) {
    if (!activeNotifications.includes(entry)) return;

    entry.el.classList.remove('show');
    entry.el.classList.add('hide');

    setTimeout(() => {
        entry.el.remove();
        activeNotifications = activeNotifications.filter((n) => n !== entry);
        repositionAll();
    }, 300);
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'notify') {
        addNotification({
            message: data.message,
            type: data.type,
            duration: data.duration
        });
    }
});
