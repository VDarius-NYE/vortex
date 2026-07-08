function getResourceName() {
    return (typeof GetParentResourceName === 'function') ? GetParentResourceName() : window.location.hostname;
}

function nuiFetch(endpoint, data) {
    return fetch(`https://${getResourceName()}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {})
    }).then((r) => r.json().catch(() => ({})));
}

const app = document.getElementById('app');
const loadingState = document.getElementById('loadingState');
const logList = document.getElementById('logList');
const emptyState = document.getElementById('emptyState');
const searchInput = document.getElementById('searchInput');
const entryCount = document.getElementById('entryCount');
const tooltip = document.getElementById('tooltip');

let allRows = [];

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text == null ? '' : String(text);
    return div.innerHTML;
}

function formatTimestamp(value) {
    const date = new Date(Number(value));
    if (isNaN(date.getTime())) return '';
    const pad = (n) => String(n).padStart(2, '0');
    return `${date.getFullYear()}.${pad(date.getMonth() + 1)}.${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function buildEntry(row) {
    const el = document.createElement('div');
    el.className = 'log-entry';

    const weaponKey = (row.weapon || '').toLowerCase();

    el.innerHTML = `
        <div class="log-weapon-wrap">
            <img class="log-weapon-img" src="nui://nb_inventory/html/assets/items/${weaponKey}.png" alt="">
            <i class="fa-solid fa-gun log-weapon-fallback hidden"></i>
        </div>
        <div class="log-text">
            <span class="killer-name">${escapeHtml(row.killer_name)}</span><span class="pid">(${row.killer_id})</span>
            megölte
            <span class="victim-name">${escapeHtml(row.victim_name)}</span><span class="pid">(${row.victim_id})</span>
            játékost.
        </div>
        <div class="log-timestamp">${formatTimestamp(row.created_at)}</div>
    `;

    const img = el.querySelector('.log-weapon-img');
    const fallback = el.querySelector('.log-weapon-fallback');
    img.addEventListener('error', () => {
        img.classList.add('hidden');
        fallback.classList.remove('hidden');
    });

    const weaponWrap = el.querySelector('.log-weapon-wrap');
    weaponWrap.addEventListener('mouseenter', (e) => {
        let html = `<div>${escapeHtml(row.weapon || 'Ismeretlen fegyver')}</div>`;
        if (row.weapon_serial) {
            html += `<div class="tt-serial">Serial: ${escapeHtml(row.weapon_serial)}</div>`;
        }
        tooltip.innerHTML = html;
        tooltip.classList.remove('hidden');
        moveTooltip(e);
    });
    weaponWrap.addEventListener('mousemove', moveTooltip);
    weaponWrap.addEventListener('mouseleave', () => tooltip.classList.add('hidden'));

    return el;
}

function moveTooltip(e) {
    tooltip.style.left = (e.clientX + 14) + 'px';
    tooltip.style.top = (e.clientY + 14) + 'px';
}

function renderList(rows) {
    logList.innerHTML = '';

    if (rows.length === 0) {
        logList.classList.add('hidden');
        emptyState.classList.remove('hidden');
        return;
    }

    emptyState.classList.add('hidden');
    logList.classList.remove('hidden');

    rows.forEach((row) => logList.appendChild(buildEntry(row)));
}

function applySearch() {
    const term = searchInput.value.trim().toLowerCase();

    let filtered = allRows;
    if (term) {
        filtered = allRows.filter((row) => {
            return (row.killer_name || '').toLowerCase().includes(term)
                || (row.victim_name || '').toLowerCase().includes(term)
                || String(row.killer_id).includes(term)
                || String(row.victim_id).includes(term);
        });
    }

    entryCount.textContent = `${filtered.length} / ${allRows.length} bejegyzés`;
    renderList(filtered);
}

searchInput.addEventListener('input', applySearch);

document.getElementById('closeBtn').addEventListener('click', () => {
    nuiFetch('closeKillLog', {});
    app.classList.add('hidden');
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        nuiFetch('closeKillLog', {});
        app.classList.add('hidden');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'loading') {
        app.classList.remove('hidden');
        loadingState.classList.remove('hidden');
        logList.classList.add('hidden');
        emptyState.classList.add('hidden');
        searchInput.value = '';
        entryCount.textContent = '';
    } else if (data.action === 'show') {
        allRows = data.rows || [];
        loadingState.classList.add('hidden');
        entryCount.textContent = `${allRows.length} / ${allRows.length} bejegyzés`;
        renderList(allRows);
    } else if (data.action === 'close') {
        app.classList.add('hidden');
        tooltip.classList.add('hidden');
    }
});
