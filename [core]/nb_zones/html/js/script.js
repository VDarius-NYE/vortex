const zonePanel = document.getElementById('zonePanel');
const zoneIcon = document.getElementById('zoneIcon');
const zoneTitle = document.getElementById('zoneTitle');
const zoneMessage = document.getElementById('zoneMessage');

const typeMeta = {
    safe: { icon: 'fa-solid fa-shield-halved', title: 'Biztonságos zóna' },
    faction: { icon: 'fa-solid fa-flag', title: 'Frakció zóna' },
    danger: { icon: 'fa-solid fa-triangle-exclamation', title: 'Veszélyes zóna' },
    admin: { icon: 'fa-solid fa-user-shield', title: 'Admin zóna' }
};

let hideTimeout = null;
let fadeTimeout = null;

function clearTimers() {
    if (hideTimeout) { clearTimeout(hideTimeout); hideTimeout = null; }
    if (fadeTimeout) { clearTimeout(fadeTimeout); fadeTimeout = null; }
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'show') {
        clearTimers();

        const meta = typeMeta[data.type] || { icon: 'fa-solid fa-info-circle', title: 'Zóna Infó' };
        zoneIcon.className = meta.icon;
        zoneTitle.textContent = meta.title;
        zoneMessage.textContent = data.message;

        zonePanel.classList.add('hidden');
        zonePanel.classList.remove('fade-out');
        void zonePanel.offsetWidth; // reflow, hogy az animáció újrainduljon
        zonePanel.className = `type-${data.type}`;

        // 20 másodperc után animálva eltűnik, akkor is ha még bent vagyunk
        // a zónában - nem kell folyamatosan kint tartani a képernyőn.
        hideTimeout = setTimeout(() => {
            zonePanel.classList.add('fade-out');
            fadeTimeout = setTimeout(() => {
                zonePanel.classList.add('hidden');
            }, 500);
        }, 20000);
    } else if (data.action === 'hide') {
        clearTimers();
        zonePanel.classList.add('hidden');
        zonePanel.classList.remove('fade-out');
    }
});
