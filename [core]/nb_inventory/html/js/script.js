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
const tooltip = document.getElementById('tooltip');
const actionBar = document.getElementById('actionBar');
const popupStack = document.getElementById('popupStack');

let state = {
    player: null,
    stash: null,
    selected: null // { side, slot, stashId }
};

let hoveredSlot = null;
let dragState = null; // { side, slot, stashId, ghostEl }

function itemTypeClass(itemType) {
    if (itemType === 'money') return 'money';
    if (itemType === 'weapon') return 'weapon';
    if (itemType === 'ammo') return 'ammo';
    return '';
}

// ============================================================
// Egér-alapú drag & drop (nem natív HTML5 DnD, mert az nem megbízható
// ebben a CEF környezetben - ugyanaz a technika, mint a mozgatható paneleknél)
// ============================================================
function startCustomDrag(e, side, slotIndex, data, stashId) {
    e.preventDefault();

    const ghost = document.createElement('div');
    ghost.className = 'drag-ghost';
    const img = document.createElement('img');
    img.src = `assets/items/${data.item.toLowerCase()}.png`;
    img.onerror = () => { img.style.display = 'none'; };
    ghost.appendChild(img);
    document.body.appendChild(ghost);

    dragState = { side, slot: slotIndex, stashId, ghostEl: ghost };
    moveGhost(e);
}

function moveGhost(e) {
    if (!dragState) return;
    dragState.ghostEl.style.left = e.clientX + 'px';
    dragState.ghostEl.style.top = e.clientY + 'px';
}

document.addEventListener('mousemove', (e) => {
    if (dragState) moveGhost(e);
});

document.addEventListener('mouseup', () => {
    if (!dragState) return;

    dragState.ghostEl.remove();

    if (hoveredSlot) {
        nuiFetch('moveItem', {
            fromSide: dragState.side,
            fromSlot: dragState.slot,
            toSide: hoveredSlot.side,
            toSlot: hoveredSlot.slot,
            stashId: (dragState.stashId || hoveredSlot.stashId)
        });
    } else {
        // Az inventory-n KÍVÜLRE ejtette -> eldobja az itemet
        nuiFetch('dropItem', {
            side: dragState.side,
            slot: dragState.slot,
            stashId: dragState.stashId
        });
    }

    document.querySelectorAll('.slot.drag-over').forEach((el) => el.classList.remove('drag-over'));
    dragState = null;
});

function buildSlot(side, slotIndex, data, stashId) {
    const slot = document.createElement('div');
    slot.className = 'slot';
    if (side === 'player' && slotIndex <= 5) {
        slot.classList.add('hotbar');
        slot.dataset.hotbarIndex = slotIndex;
    }
    slot.dataset.side = side;
    slot.dataset.slot = slotIndex;

    if (data) {
        const iconWrap = document.createElement('div');
        iconWrap.className = 'slot-icon-wrap';

        const img = document.createElement('img');
        img.className = 'slot-icon-img';
        img.src = `assets/items/${data.item.toLowerCase()}.png`;
        img.alt = data.label;

        const fallback = document.createElement('i');
        fallback.className = `slot-icon fallback hidden ${data.icon} ${itemTypeClass(data.itemType)}`;

        img.addEventListener('error', () => {
            img.classList.add('hidden');
            fallback.classList.remove('hidden');
        });

        iconWrap.appendChild(img);
        iconWrap.appendChild(fallback);
        slot.appendChild(iconWrap);

        if (data.quantity > 1) {
            const qty = document.createElement('div');
            qty.className = 'slot-qty';
            qty.textContent = data.quantity;
            slot.appendChild(qty);
        }

        if (data.hasDurability) {
            const durTrack = document.createElement('div');
            durTrack.className = 'slot-durability';
            const durFill = document.createElement('div');
            durFill.className = 'slot-durability-fill';
            const durability = data.metadata && data.metadata.durability != null ? data.metadata.durability : 100;
            durFill.style.width = `${Math.max(0, Math.min(100, durability))}%`;
            durTrack.appendChild(durFill);
            slot.appendChild(durTrack);
        }

        slot.addEventListener('mousedown', (e) => {
            if (e.button !== 0) return; // csak bal klikk indítja a húzást
            startCustomDrag(e, side, slotIndex, data, stashId);
        });

        slot.addEventListener('mouseenter', (e) => showTooltip(e, data));
        slot.addEventListener('mousemove', (e) => moveTooltip(e));
        slot.addEventListener('mouseleave', hideTooltip);

        slot.addEventListener('click', () => selectSlot(side, slotIndex, data, stashId));
    }

    // Hover-követés a saját (egér-alapú) drag rendszerhez - MINDEN slotra kell,
    // hogy üres slotba is lehessen ejteni.
    slot.addEventListener('mouseenter', () => {
        hoveredSlot = { side, slot: slotIndex, stashId };
        if (dragState) slot.classList.add('drag-over');
    });
    slot.addEventListener('mouseleave', () => {
        if (hoveredSlot && hoveredSlot.side === side && hoveredSlot.slot === slotIndex) {
            hoveredSlot = null;
        }
        slot.classList.remove('drag-over');
    });

    if (state.selected && state.selected.side === side && state.selected.slot === slotIndex) {
        slot.classList.add('selected');
    }

    return slot;
}

function renderGrid(containerId, side, payload, stashId) {
    const container = document.getElementById(containerId);
    container.innerHTML = '';
    if (!payload) return;

    for (let i = 1; i <= payload.maxSlots; i++) {
        const data = payload.slots[String(i)];
        container.appendChild(buildSlot(side, i, data, stashId));
    }
}

function renderWeight(labelId, fillId, payload) {
    const label = document.getElementById(labelId);
    const fill = document.getElementById(fillId);
    if (!payload) return;

    label.textContent = `${Math.round(payload.weight)}/${payload.maxWeight}kg`;
    const pct = Math.min(100, (payload.weight / payload.maxWeight) * 100);
    fill.style.width = pct + '%';

    fill.classList.remove('warn', 'danger');
    if (pct >= 90) fill.classList.add('danger');
    else if (pct >= 70) fill.classList.add('warn');
}

function renderAll() {
    renderGrid('playerGrid', 'player', state.player, null);
    renderWeight('playerWeightLabel', 'playerWeightFill', state.player);

    const stashPanel = document.getElementById('stashPanel');
    if (state.stash) {
        stashPanel.classList.remove('hidden');
        const title = state.stash.factionId === 'GROUND'
            ? `FÖLD — #${state.stash.stashId}`
            : `STASH #${state.stash.stashId} — ${state.stash.factionId || ''}`;
        document.getElementById('stashTitle').textContent = title;
        renderGrid('stashGrid', 'stash', state.stash, state.stash.stashId);
        renderWeight('stashWeightLabel', 'stashWeightFill', state.stash);
    } else {
        stashPanel.classList.add('hidden');
    }
}

// ============================================================
// Tooltip
// ============================================================
function showTooltip(e, data) {
    let html = `<div class="tt-title">${escapeHtml(data.label)}</div>`;
    html += `<div class="tt-row"><span>Mennyiség</span><span>${data.quantity} db</span></div>`;

    if (data.hasDurability) {
        const durability = data.metadata && data.metadata.durability != null ? Math.round(data.metadata.durability) : 100;
        html += `<div class="tt-row"><span>Durability</span><span>${durability}%</span></div>`;
    }
    if (data.hasSerial && data.metadata && data.metadata.serial) {
        html += `<div class="tt-row"><span>Serial</span><span>${escapeHtml(data.metadata.serial)}</span></div>`;
    }

    tooltip.innerHTML = html;
    tooltip.classList.remove('hidden');
    moveTooltip(e);
}

function moveTooltip(e) {
    tooltip.style.left = (e.clientX + 16) + 'px';
    tooltip.style.top = (e.clientY + 16) + 'px';
}

function hideTooltip() {
    tooltip.classList.add('hidden');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text == null ? '' : String(text);
    return div.innerHTML;
}

// ============================================================
// Kijelölés + action bar
// ============================================================
function selectSlot(side, slotIndex, data, stashId) {
    state.selected = { side, slot: slotIndex, stashId };
    renderAll();

    document.getElementById('actionItemName').textContent = data.label;
    document.getElementById('useBtn').classList.toggle('hidden', side !== 'player' || !data.usable);
    document.getElementById('halfBtn').classList.toggle('hidden', !data.stackable || data.quantity < 2);
    document.getElementById('customAmountInput').classList.toggle('hidden', !data.stackable || data.quantity < 2);
    document.getElementById('customSplitBtn').classList.toggle('hidden', !data.stackable || data.quantity < 2);

    actionBar.classList.remove('hidden');
}

function deselect() {
    state.selected = null;
    actionBar.classList.add('hidden');
    renderAll();
}

document.getElementById('deselectBtn').addEventListener('click', deselect);

document.getElementById('useBtn').addEventListener('click', () => {
    if (!state.selected) return;
    const payload = state.selected.side === 'stash' ? state.stash : state.player;
    const data = payload.slots[String(state.selected.slot)];
    nuiFetch('useItem', { side: state.selected.side, slot: state.selected.slot, stashId: state.selected.stashId, item: data ? data.item : null });
    deselect();
});

document.getElementById('halfBtn').addEventListener('click', () => {
    if (!state.selected) return;
    const payload = state.selected.side === 'stash' ? state.stash : state.player;
    const data = payload.slots[String(state.selected.slot)];
    if (!data) return;
    const amount = Math.floor(data.quantity / 2);
    if (amount <= 0) return;

    nuiFetch('splitItem', { side: state.selected.side, slot: state.selected.slot, amount, stashId: state.selected.stashId });
    deselect();
});

document.getElementById('customSplitBtn').addEventListener('click', () => {
    if (!state.selected) return;
    const amount = parseInt(document.getElementById('customAmountInput').value, 10);
    if (!amount || amount <= 0) return;

    nuiFetch('splitItem', { side: state.selected.side, slot: state.selected.slot, amount, stashId: state.selected.stashId });
    deselect();
});

document.getElementById('dropBtn').addEventListener('click', () => {
    if (!state.selected) return;
    nuiFetch('dropItem', { side: state.selected.side, slot: state.selected.slot, stashId: state.selected.stashId });
    deselect();
});

document.getElementById('closeBtn').addEventListener('click', () => {
    nuiFetch('closeInventory', {});
    app.classList.add('hidden');
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        nuiFetch('closeInventory', {});
        app.classList.add('hidden');
    }
});

// ============================================================
// Mozgatható panelek (saját inventory + stash külön-külön)
// ============================================================
let dragPanel = null;

function makeDraggable(panelEl, headerEl, panelKey) {
    headerEl.addEventListener('mousedown', (e) => {
        const rect = panelEl.getBoundingClientRect();
        dragPanel = {
            el: panelEl,
            key: panelKey,
            offsetX: e.clientX - rect.left,
            offsetY: e.clientY - rect.top
        };
    });
}

document.addEventListener('mousemove', (e) => {
    if (!dragPanel) return;
    const x = e.clientX - dragPanel.offsetX;
    const y = e.clientY - dragPanel.offsetY;
    dragPanel.el.style.left = x + 'px';
    dragPanel.el.style.top = y + 'px';
});

document.addEventListener('mouseup', () => {
    if (!dragPanel) return;
    const rect = dragPanel.el.getBoundingClientRect();
    nuiFetch('savePosition', { panel: dragPanel.key, x: rect.left, y: rect.top });
    dragPanel = null;
});

function applyPanelPosition(panelEl, pos, defaultLeft, defaultTop) {
    if (pos && typeof pos.x === 'number' && typeof pos.y === 'number') {
        panelEl.style.left = pos.x + 'px';
        panelEl.style.top = pos.y + 'px';
    } else {
        panelEl.style.left = defaultLeft + 'px';
        panelEl.style.top = defaultTop + 'px';
    }
}

const playerPanelEl = document.getElementById('playerPanel');
const stashPanelEl = document.getElementById('stashPanel');
makeDraggable(playerPanelEl, playerPanelEl.querySelector('.panel-header'), 'player');
makeDraggable(stashPanelEl, stashPanelEl.querySelector('.panel-header'), 'stash');

// ============================================================
// Popup értesítések (kapott / használt / eldobott item)
// ============================================================
const MAX_POPUPS = 5;
let activePopups = [];

function addPopup(data) {
    if (activePopups.length >= MAX_POPUPS) {
        const oldest = activePopups.shift();
        if (oldest.timeoutId) clearTimeout(oldest.timeoutId);
        oldest.el.remove();
    }

    const el = document.createElement('div');
    el.className = 'popup-item';

    const iconWrap = document.createElement('div');
    iconWrap.className = 'popup-icon-wrap';

    const img = document.createElement('img');
    img.className = 'popup-icon-img';
    img.src = `assets/items/${(data.item || '').toLowerCase()}.png`;

    const fallback = document.createElement('i');
    fallback.className = 'fa-solid fa-cube popup-icon-fallback hidden';

    img.addEventListener('error', () => {
        img.classList.add('hidden');
        fallback.classList.remove('hidden');
    });

    iconWrap.appendChild(img);
    iconWrap.appendChild(fallback);

    const text = document.createElement('div');
    text.className = 'popup-text';
    text.textContent = data.text;

    el.appendChild(iconWrap);
    el.appendChild(text);
    popupStack.appendChild(el);

    requestAnimationFrame(() => el.classList.add('show'));

    const entry = { el, timeoutId: null };
    entry.timeoutId = setTimeout(() => {
        el.classList.remove('show');
        setTimeout(() => {
            el.remove();
            activePopups = activePopups.filter((p) => p !== entry);
        }, 300);
    }, 4000);

    activePopups.push(entry);
}

// ============================================================
// Lua -> JS üzenetek
// ============================================================
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        state.player = data.player;
        state.stash = data.stash || null;
        state.selected = null;
        actionBar.classList.add('hidden');

        const positions = data.positions || {};
        applyPanelPosition(playerPanelEl, positions.player, 60, Math.round(window.innerHeight / 2 - 260));
        applyPanelPosition(stashPanelEl, positions.stash, 470, Math.round(window.innerHeight / 2 - 260));

        app.classList.remove('hidden');
        renderAll();

        nuiFetch('inventoryReady', {});
    } else if (data.action === 'update') {
        state.player = data.player;
        state.stash = data.stash || null;
        renderAll();
    } else if (data.action === 'close') {
        app.classList.add('hidden');
        hideTooltip();
    } else if (data.action === 'popup') {
        addPopup(data);
    }
});
