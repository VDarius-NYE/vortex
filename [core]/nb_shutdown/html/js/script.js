const panel = document.getElementById('shutdownPanel');
const countdownEl = document.getElementById('countdown');
const reasonEl = document.getElementById('reason');
const sound = document.getElementById('countdownSound');

let localSeconds = 0;
let tickInterval = null;

function formatTime(totalSeconds) {
    const m = Math.floor(totalSeconds / 60);
    const s = totalSeconds % 60;
    return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function startLocalTick() {
    if (tickInterval) clearInterval(tickInterval);
    tickInterval = setInterval(() => {
        if (localSeconds > 0) {
            localSeconds -= 1;
            countdownEl.textContent = formatTime(localSeconds);
        }
    }, 1000);
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'show') {
        panel.classList.remove('hidden');
        reasonEl.textContent = `Indok: ${data.reason}`;

        // A szerver percenként küld frissítést - ilyenkor szinkronizáljuk a
        // helyi (másodperces) visszaszámlálót, ami köztük simán, folyamatosan
        // pörög tovább.
        localSeconds = data.minutes * 60;
        countdownEl.textContent = formatTime(localSeconds);
        startLocalTick();

        if (data.minutes <= 0) {
            clearInterval(tickInterval);
        }
    } else if (data.action === 'playSound') {
        try {
            sound.currentTime = 0;
            sound.play().catch(() => {});
        } catch (e) {}
    } else if (data.action === 'hide') {
        if (tickInterval) clearInterval(tickInterval);
        panel.classList.add('hidden');
    }
});
