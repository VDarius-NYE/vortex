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
const playerRows = document.getElementById('playerRows');
const myGroupBadge = document.getElementById('myGroupBadge');

let state = {
    players: [],
    groups: ['user', 'support', 'admin', 'owner'],
    myGroup: 'user',
    onDuty: false
};

const dutyBtn = document.getElementById('dutyBtn');

function updateDutyBtn() {
    dutyBtn.textContent = state.onDuty ? 'SZOLGÁLATBÓL KILÉPÉS' : 'SZOLGÁLATBA LÉPÉS';
    dutyBtn.classList.toggle('active', state.onDuty);
}

dutyBtn.addEventListener('click', () => {
    nuiFetch('toggleDuty', {});
});

function renderPlayers() {
    playerRows.innerHTML = '';

    if (state.players.length === 0) {
        playerRows.innerHTML = '<tr class="empty-row"><td colspan="4">Nincs több online játékos.</td></tr>';
        return;
    }

    state.players.forEach((player) => {
        const tr = document.createElement('tr');

        const idTd = document.createElement('td');
        idTd.textContent = player.id;

        const nameTd = document.createElement('td');
        nameTd.textContent = player.name;
        if (player.onDuty) {
            const tag = document.createElement('span');
            tag.className = 'duty-tag';
            tag.textContent = 'SZOLGÁLATBAN';
            nameTd.appendChild(tag);
        }

        const groupTd = document.createElement('td');
        const select = document.createElement('select');
        select.className = 'group-select';
        state.groups.forEach((g) => {
            const opt = document.createElement('option');
            opt.value = g;
            opt.textContent = g;
            if (g === player.group) opt.selected = true;
            select.appendChild(opt);
        });
        groupTd.appendChild(select);

        const actionsTd = document.createElement('td');
        const actionsWrap = document.createElement('div');
        actionsWrap.className = 'actions-cell';

        actionsWrap.appendChild(makeActionBtn('Részletek', () => openDetails(player.id)));
        actionsWrap.appendChild(makeActionBtn('TP', () => doAction('tp', player.id)));
        actionsWrap.appendChild(makeActionBtn('Hozás', () => doAction('bring', player.id)));
        actionsWrap.appendChild(makeActionBtn('Feltámaszt', () => doAction('revive', player.id)));
        actionsWrap.appendChild(makeActionBtn('Gyógyít', () => doAction('heal', player.id)));

        const reasonInput = document.createElement('input');
        reasonInput.type = 'text';
        reasonInput.className = 'reason-input';
        reasonInput.placeholder = 'Indok...';

        actionsWrap.appendChild(reasonInput);
        actionsWrap.appendChild(makeActionBtn('Kick', () => doAction('kick', player.id, { reason: reasonInput.value }), true));
        actionsWrap.appendChild(makeActionBtn('Ban', () => doAction('ban', player.id, { reason: reasonInput.value }), true));

        const applyGroupBtn = makeActionBtn('Mentés', () => doAction('setgroup', player.id, { group: select.value }));
        actionsWrap.appendChild(applyGroupBtn);

        actionsTd.appendChild(actionsWrap);

        tr.appendChild(idTd);
        tr.appendChild(nameTd);
        tr.appendChild(groupTd);
        tr.appendChild(actionsTd);
        playerRows.appendChild(tr);
    });
}

function makeActionBtn(label, onClick, danger = false) {
    const btn = document.createElement('button');
    btn.className = 'action-btn' + (danger ? ' danger' : '');
    btn.textContent = label;
    btn.addEventListener('click', onClick);
    return btn;
}

function doAction(action, targetId, extra = {}) {
    nuiFetch('panelAction', { action, targetId, ...extra });
}

document.getElementById('closeBtn').addEventListener('click', () => {
    nuiFetch('closePanel', {});
    app.classList.add('hidden');
});

document.getElementById('refreshBtn').addEventListener('click', () => {
    nuiFetch('refreshPanel', {});
});

// ============================================================
// RÉSZLETEK MODAL
// ============================================================
const detailsModal = document.getElementById('detailsModal');
const detailsBody = document.getElementById('detailsBody');
const detailsTitle = document.getElementById('detailsTitle');

let currentDetailsTargetId = null;

function openDetails(targetId) {
    currentDetailsTargetId = targetId;
    nuiFetch('requestDetails', { targetId });
}

function closeDetails() {
    detailsModal.classList.add('hidden');
    currentDetailsTargetId = null;
}

document.getElementById('closeDetailsBtn').addEventListener('click', closeDetails);

function copyToClipboard(text, btn) {
    if (!text) return;
    navigator.clipboard.writeText(String(text)).then(() => {
        const original = btn.textContent;
        btn.textContent = 'Másolva!';
        btn.classList.add('copied');
        setTimeout(() => {
            btn.textContent = original;
            btn.classList.remove('copied');
        }, 1200);
    }).catch(() => {});
}

function formatDate(value) {
    if (!value) return 'Nincs adat';

    let date;
    if (typeof value === 'number') {
        date = new Date(value);
    } else if (/^\d+$/.test(String(value))) {
        date = new Date(Number(value));
    } else {
        date = new Date(String(value).replace(' ', 'T'));
    }

    if (isNaN(date.getTime())) return String(value);

    const pad = (n) => String(n).padStart(2, '0');
    return `${date.getFullYear()}.${pad(date.getMonth() + 1)}.${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function formatPlaytime(minutes) {
    if (!minutes) return '0 perc';
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return h > 0 ? `${h} óra ${m} perc` : `${m} perc`;
}

function makeDetailField(label, value, sensitive = false) {
    const wrap = document.createElement('div');
    wrap.className = 'detail-field';

    const labelEl = document.createElement('span');
    labelEl.className = 'field-label';
    labelEl.textContent = label;

    const valueEl = document.createElement('span');
    valueEl.className = 'field-value' + (sensitive ? ' sensitive' : '');
    valueEl.textContent = value || 'Nincs adat';

    wrap.appendChild(labelEl);
    wrap.appendChild(valueEl);

    if (sensitive && value) {
        const btn = document.createElement('button');
        btn.className = 'copy-btn';
        btn.textContent = 'Másolás';
        btn.addEventListener('click', () => copyToClipboard(value, btn));
        wrap.appendChild(btn);
    }

    return wrap;
}

function renderDetails(details) {
    detailsTitle.textContent = `Részletek — ${state.players.find(p => p.id === details.targetId)?.name || ('Player #' + details.targetId)}`;
    detailsBody.innerHTML = '';

    const acc = details.account || {};
    const canDeleteWarn = state.myGroup === 'owner';

    // ---- Account szekció ----
    const accSection = document.createElement('div');
    accSection.className = 'detail-section';
    accSection.innerHTML = '<h3>Account infó</h3>';
    const accGrid = document.createElement('div');
    accGrid.className = 'detail-grid';
    accGrid.appendChild(makeDetailField('Identifier', acc.identifier, true));
    accGrid.appendChild(makeDetailField('Discord', acc.discord, true));
    accGrid.appendChild(makeDetailField('Steam', acc.steam, true));
    accGrid.appendChild(makeDetailField('Felhasználónév', acc.username));
    accGrid.appendChild(makeDetailField('Email', acc.email, true));
    accGrid.appendChild(makeDetailField('Játékidő', formatPlaytime(acc.playtime)));
    accGrid.appendChild(makeDetailField('Csoport', acc.group));
    accGrid.appendChild(makeDetailField('Regisztrált', formatDate(acc.created_at)));
    accGrid.appendChild(makeDetailField('Utoljára frissítve', formatDate(acc.updated_at)));
    accGrid.appendChild(makeDetailField('Utolsó belépés', formatDate(acc.last_login)));
    accSection.appendChild(accGrid);
    detailsBody.appendChild(accSection);

    // ---- Karakter szekció ----
    const charSection = document.createElement('div');
    charSection.className = 'detail-section';
    charSection.innerHTML = '<h3>Karakter</h3>';
    const charGrid = document.createElement('div');
    charGrid.className = 'detail-grid';
    if (details.character) {
        charGrid.appendChild(makeDetailField('Modell', details.character.model === 'mp_f_freemode_01' ? 'Nő' : 'Férfi'));
        charGrid.appendChild(makeDetailField('Karakter létrehozva', formatDate(details.character.created_at)));
        charGrid.appendChild(makeDetailField('Karakter frissítve', formatDate(details.character.updated_at)));
    } else {
        charGrid.innerHTML = '<div class="history-empty">Még nincs mentett karaktere.</div>';
    }
    charSection.appendChild(charGrid);
    detailsBody.appendChild(charSection);

    // ---- Gazdaság + statok (placeholder, későbbi rendszer) ----
    const statsSection = document.createElement('div');
    statsSection.className = 'detail-section';
    statsSection.innerHTML = '<h3>Gazdaság &amp; Statisztika</h3>';
    const statBoxes = document.createElement('div');
    statBoxes.className = 'stat-boxes';

    const boxes = [
        ['Készpénz', details.economy?.cash],
        ['Banki egyenleg', details.economy?.bank],
        ['Kill / Death', (details.stats?.kills != null && details.stats?.deaths != null) ? `${details.stats.kills} / ${details.stats.deaths}` : null],
        ['K/D arány', null]
    ];
    boxes.forEach(([label, value]) => {
        const box = document.createElement('div');
        box.className = 'stat-box' + (value == null ? ' placeholder' : '');
        box.innerHTML = `<div class="stat-value">${value != null ? value : 'Hamarosan'}</div><div class="stat-label">${label}</div>`;
        statBoxes.appendChild(box);
    });
    statsSection.appendChild(statBoxes);
    detailsBody.appendChild(statsSection);

    // ---- Figyelmeztetések ----
    const warnSection = document.createElement('div');
    warnSection.className = 'detail-section';
    warnSection.innerHTML = '<h3>Figyelmeztetések (Warnok)</h3>';
    const warnList = document.createElement('div');
    warnList.className = 'history-list';

    if (!details.warns || details.warns.length === 0) {
        warnList.innerHTML = '<div class="history-empty">Nincs figyelmeztetése.</div>';
    } else {
        details.warns.forEach((warn) => {
            const item = document.createElement('div');
            item.className = 'history-item';
            const main = document.createElement('div');
            main.className = 'history-main';
            main.innerHTML = `${escapeHtml(warn.reason)}<div class="history-meta">${escapeHtml(warn.admin_name || 'Ismeretlen')} — ${formatDate(warn.created_at)}</div>`;
            item.appendChild(main);

            if (canDeleteWarn) {
                const delBtn = document.createElement('button');
                delBtn.className = 'delete-warn-btn';
                delBtn.textContent = 'Törlés';
                delBtn.addEventListener('click', () => {
                    nuiFetch('deleteWarn', { warnId: warn.id, targetId: details.targetId });
                });
                item.appendChild(delBtn);
            }

            warnList.appendChild(item);
        });
    }
    warnSection.appendChild(warnList);

    const warnAddRow = document.createElement('div');
    warnAddRow.className = 'warn-add-row';
    const warnInput = document.createElement('input');
    warnInput.type = 'text';
    warnInput.placeholder = 'Figyelmeztetés indoka...';
    const warnAddBtn = document.createElement('button');
    warnAddBtn.className = 'action-btn';
    warnAddBtn.textContent = 'Figyelmeztetés hozzáadása';
    warnAddBtn.addEventListener('click', () => {
        if (!warnInput.value.trim()) return;
        nuiFetch('addWarn', { targetId: details.targetId, reason: warnInput.value.trim() });
        warnInput.value = '';
    });
    warnAddRow.appendChild(warnInput);
    warnAddRow.appendChild(warnAddBtn);
    warnSection.appendChild(warnAddRow);

    detailsBody.appendChild(warnSection);

    // ---- Kitiltás előzmények ----
    const banSection = document.createElement('div');
    banSection.className = 'detail-section';
    banSection.innerHTML = '<h3>Kitiltás előzmények</h3>';
    const banList = document.createElement('div');
    banList.className = 'history-list';
    if (!details.bans || details.bans.length === 0) {
        banList.innerHTML = '<div class="history-empty">Nincs korábbi kitiltása.</div>';
    } else {
        details.bans.forEach((ban) => {
            const item = document.createElement('div');
            item.className = 'history-item';
            const status = ban.expires_at ? `Lejár: ${formatDate(ban.expires_at)}` : 'Végleges';
            item.innerHTML = `<div class="history-main">${escapeHtml(ban.reason)}<div class="history-meta">${escapeHtml(ban.banned_by_name || 'Ismeretlen')} — ${formatDate(ban.banned_at)} (${status})</div></div>`;
            banList.appendChild(item);
        });
    }
    banSection.appendChild(banList);
    detailsBody.appendChild(banSection);

    // ---- Kick előzmények ----
    const kickSection = document.createElement('div');
    kickSection.className = 'detail-section';
    kickSection.innerHTML = '<h3>Kick előzmények</h3>';
    const kickList = document.createElement('div');
    kickList.className = 'history-list';
    if (!details.kicks || details.kicks.length === 0) {
        kickList.innerHTML = '<div class="history-empty">Nincs korábbi kickje.</div>';
    } else {
        details.kicks.forEach((kick) => {
            const item = document.createElement('div');
            item.className = 'history-item';
            item.innerHTML = `<div class="history-main">${escapeHtml(kick.reason)}<div class="history-meta">${escapeHtml(kick.admin_name || 'Ismeretlen')} — ${formatDate(kick.created_at)}</div></div>`;
            kickList.appendChild(item);
        });
    }
    kickSection.appendChild(kickList);
    detailsBody.appendChild(kickSection);

    detailsModal.classList.remove('hidden');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text == null ? '' : String(text);
    return div.innerHTML;
}

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        state.players = data.players || [];
        state.groups = data.groups || state.groups;
        state.myGroup = data.myGroup || 'user';
        state.onDuty = false;
        myGroupBadge.textContent = state.myGroup.toUpperCase();
        updateDutyBtn();

        app.classList.remove('hidden');
        renderPlayers();

        nuiFetch('panelReady', {});
    } else if (data.action === 'updatePlayers') {
        state.players = data.players || [];
        renderPlayers();
    } else if (data.action === 'dutyState') {
        state.onDuty = data.onDuty;
        updateDutyBtn();
    } else if (data.action === 'showDetails') {
        renderDetails(data.details);
    } else if (data.action === 'close') {
        app.classList.add('hidden');
        closeDetails();
    }
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        if (!detailsModal.classList.contains('hidden')) {
            closeDetails();
        } else {
            nuiFetch('closePanel', {});
            app.classList.add('hidden');
        }
    }
});
