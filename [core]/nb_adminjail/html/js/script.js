const loadingScreen = document.getElementById('loadingScreen');
const jailPanel = document.getElementById('jailPanel');
const jailCountdown = document.getElementById('jailCountdown');
const jailReason = document.getElementById('jailReason');
const jailAdmin = document.getElementById('jailAdmin');

let remaining = 0;
let tickInterval = null;

function formatTime(totalSeconds) {
    totalSeconds = Math.max(0, totalSeconds);
    const h = Math.floor(totalSeconds / 3600);
    const m = Math.floor((totalSeconds % 3600) / 60);
    const s = totalSeconds % 60;
    if (h > 0) {
        return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
    }
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function startTick() {
    if (tickInterval) clearInterval(tickInterval);
    tickInterval = setInterval(() => {
        if (remaining > 0) {
            remaining -= 1;
            jailCountdown.textContent = formatTime(remaining);
        }
    }, 1000);
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'showLoading') {
        loadingScreen.classList.remove('hidden');
        // Az animációt (loading-bar-fill) újraindítjuk minden alkalommal
        const fill = document.querySelector('.loading-bar-fill');
        fill.style.animation = 'none';
        void fill.offsetWidth;
        fill.style.animation = null;
    } else if (data.action === 'hideLoading') {
        loadingScreen.classList.add('hidden');
    } else if (data.action === 'showJail') {
        remaining = data.remainingSeconds || 0;
        jailReason.textContent = data.reason || '';
        jailAdmin.textContent = data.adminName || '';
        jailCountdown.textContent = formatTime(remaining);
        jailPanel.classList.remove('hidden');
        startTick();
    } else if (data.action === 'hideJail') {
        jailPanel.classList.add('hidden');
        if (tickInterval) clearInterval(tickInterval);
    }
});
