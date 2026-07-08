const deathScreen = document.getElementById('deathScreen');
const killerLine = document.getElementById('killerLine');
const countdownEl = document.getElementById('countdown');

function formatTime(totalSeconds) {
    const m = Math.floor(totalSeconds / 60);
    const s = totalSeconds % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

// Nem lehet bezárni - se ESC, se semmilyen gomb nincs, csak a szerver
// zárhatja (respawn/admin revive), tehát szándékosan NINCS ide keydown
// vagy close callback bekötve.

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'show') {
        if (data.killerName) {
            killerLine.textContent = `Megölt téged: ${data.killerName}.`;
            killerLine.classList.remove('hidden');
        } else {
            killerLine.classList.add('hidden');
        }
        deathScreen.classList.remove('hidden');
    } else if (data.action === 'updateTimer') {
        countdownEl.textContent = formatTime(data.seconds);
    } else if (data.action === 'hide') {
        deathScreen.classList.add('hidden');
    }
});
