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

let state = {
    player: null,
    stash: null,
    selected: null // { side, slot, stashId }
};

let draggedFrom = null;

function itemTypeClass(itemType) {
    if (itemType === 'money') return 'money';
    if (itemType === 'weapon') return 'weapon';
    if (itemType === 'ammo') return 'ammo';
    return '';
}

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
        const icon = document.createElement('i');
        icon.className = `slot-icon ${data.icon} ${itemTypeClass(data.itemType)}`;
        slot.appendChild(icon);

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

        slot.draggable = true;
        slot.addEventListener('dragstart', () => {
            draggedFrom = { side, slot: slotIndex, stashId };
        });

        slot.addEventListener('mouseenter', (e) => showTooltip(e, data));
        slot.addEventListener('mousemove', (e) => moveTooltip(e));
        slot.addEventListener('mouseleave', hideTooltip);

        slot.addEventListener('click', () => selectSlot(side, slotIndex, data, stashId));
    }

    slot.addEventListener('dragover', (e) => {
        e.preventDefault();
        slot.classList.add('drag-over');
    });
    slot.addEventListener('dragleave', () => slot.classList.remove('drag-over'));
    slot.addEventListener('drop', (e) => {
        e.preventDefault();
        slot.classList.remove('drag-over');
        if (!draggedFrom) return;

        nuiFetch('moveItem', {
            fromSide: draggedFrom.side,
            fromSlot: draggedFrom.slot,
            toSide: side,
            toSlot: slotIndex,
            stashId: (draggedFrom.stashId || stashId)
        });
        draggedFrom = null;
    });

    if (side === slot.dataset.side && state.selected && state.selected.side === side && state.selected.slot === slotIndex) {
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
    fill.style.height = pct + '%';

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
        document.getElementById('stashTitle').textContent = `STASH #${state.stash.stashId} — ${state.stash.factionId || ''}`;
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
    nuiFetch('useItem', { side: state.selected.side, slot: state.selected.slot, stashId: state.selected.stashId });
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
// Lua -> JS üzenetek
// ============================================================
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        state.player = data.player;
        state.stash = data.stash || null;
        state.selected = null;
        actionBar.classList.add('hidden');

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
    }
});
