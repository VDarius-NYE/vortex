const container = document.getElementById('killfeedContainer');

const MAX_ENTRIES = 5;
const ENTRY_DURATION = 8000;

let entries = []; // { el, timeoutId }
let enabled = true;

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text == null ? '' : String(text);
    return div.innerHTML;
}

function removeEntry(entry) {
    if (!entries.includes(entry)) return;
    entry.el.classList.add('leaving');
    clearTimeout(entry.timeoutId);
    setTimeout(() => {
        entry.el.remove();
        entries = entries.filter((e) => e !== entry);
    }, 300);
}

function addEntry(data) {
    if (!enabled) return;

    // Ha már 5 van, a legrégebbi (legalul lévő) azonnal távozik, hogy legyen hely
    if (entries.length >= MAX_ENTRIES) {
        removeEntry(entries[entries.length - 1]);
    }

    const el = document.createElement('div');
    el.className = 'killfeed-entry' + (data.kind === 'generic' ? ' generic' : '');

    let textHtml;
    if (data.kind === 'generic') {
        textHtml = `<span class="victim-name">${escapeHtml(data.victim)}</span> meghalt.`;
    } else {
        textHtml = `<span class="killer-name">${escapeHtml(data.killer)}</span> megölte <span class="victim-name">${escapeHtml(data.victim)}</span> játékost.`;
    }

    let weaponHtml = '';
    if (data.kind === 'kill' && data.weapon) {
        weaponHtml = `
            <img class="killfeed-weapon-img" src="nui://nb_inventory/html/assets/items/${data.weapon.toLowerCase()}.png" alt="">
            <i class="fa-solid fa-gun killfeed-weapon-fallback hidden"></i>
        `;
    }

    el.innerHTML = `<div class="killfeed-text">${textHtml}</div>${weaponHtml}`;

    const img = el.querySelector('.killfeed-weapon-img');
    if (img) {
        const fallback = el.querySelector('.killfeed-weapon-fallback');
        img.addEventListener('error', () => {
            img.classList.add('hidden');
            fallback.classList.remove('hidden');
        });
    }

    container.prepend(el);

    const entry = { el, timeoutId: null };
    entry.timeoutId = setTimeout(() => removeEntry(entry), ENTRY_DURATION);
    entries.unshift(entry);
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'add') {
        addEntry(data.data);
    } else if (data.action === 'updatePosition') {
        const pos = data.pos;
        if (pos) {
            enabled = pos.enabled !== false;
            container.style.left = pos.xPercent + '%';
            container.style.top = pos.yPercent + '%';
            container.style.display = enabled ? 'flex' : 'none';
        }
    }
});
