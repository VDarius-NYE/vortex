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

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text == null ? '' : String(text);
    return div.innerHTML;
}

const CATEGORIES = [
    { key: 'player_report', label: 'Játékos Report' },
    { key: 'bug_report', label: 'Bug Report' },
    { key: 'question', label: 'Kérdés' },
];

// ============================================================
// Elemek
// ============================================================
const reportForm = document.getElementById('reportForm');
const categoryChoice = document.getElementById('categoryChoice');
const reportTitleInput = document.getElementById('reportTitle');
const reportDescInput = document.getElementById('reportDescription');

const adminPanel = document.getElementById('adminPanel');
const reportCards = document.getElementById('reportCards');
const reportsEmpty = document.getElementById('reportsEmpty');

const adminDetail = document.getElementById('adminDetail');
const detailHeaderTitle = document.getElementById('detailHeaderTitle');
const detailCategory = document.getElementById('detailCategory');
const detailStatus = document.getElementById('detailStatus');
const detailDescription = document.getElementById('detailDescription');
const detailClaimBtn = document.getElementById('detailClaimBtn');
const detailCloseBtn = document.getElementById('detailCloseBtn');

const chatWindow = document.getElementById('chatWindow');
const chatHeaderBar = document.getElementById('chatHeaderBar');
const chatTitle = document.getElementById('chatTitle');
const chatBell = document.getElementById('chatBell');
const chatBellCount = document.getElementById('chatBellCount');
const collapseBtn = document.getElementById('chatCollapseBtn');
const chatCategory = document.getElementById('chatCategory');
const chatStatus = document.getElementById('chatStatus');
const chatMessages = document.getElementById('chatMessages');
const chatAdminActions = document.getElementById('chatAdminActions');
const chatInput = document.getElementById('chatInput');
const chatSendBtn = document.getElementById('chatSendBtn');
const leaveChatBtn = document.getElementById('leaveChatBtn');

let selectedCategory = CATEGORIES[0].key;
let currentReport = null; // { id, isAdmin, status, claimedByName }
let unreadCount = 0;
let latestReportsList = [];
let detailTarget = null;

// ============================================================
// Player report form
// ============================================================
categoryChoice.innerHTML = CATEGORIES.map((c, i) =>
    `<button class="category-btn${i === 0 ? ' active' : ''}" data-key="${c.key}">${c.label}</button>`
).join('');

categoryChoice.querySelectorAll('.category-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
        selectedCategory = btn.dataset.key;
        categoryChoice.querySelectorAll('.category-btn').forEach((b) => b.classList.toggle('active', b === btn));
    });
});

document.getElementById('submitReportBtn').addEventListener('click', () => {
    const title = reportTitleInput.value.trim();
    const description = reportDescInput.value.trim();
    if (!title || !description) return;

    nuiFetch('submitReport', { category: selectedCategory, title, description });
    reportTitleInput.value = '';
    reportDescInput.value = '';
});

// ============================================================
// Admin panel - lista
// ============================================================
function categoryLabelFor(row) {
    return row.categoryLabel || row.category;
}

function renderCards(list) {
    latestReportsList = list;
    reportCards.innerHTML = '';

    if (!list || list.length === 0) {
        reportsEmpty.classList.remove('hidden');
        return;
    }
    reportsEmpty.classList.add('hidden');

    list.forEach((row) => {
        const card = document.createElement('div');
        card.className = 'report-card' + (row.status === 'claimed' ? ' claimed' : '');
        card.innerHTML = `
            <div class="card-id">#${row.id}</div>
            <div class="card-info">
                <div class="card-title">${escapeHtml(row.title)}</div>
                <div class="card-sub"><span class="card-player">${escapeHtml(row.playerName)}</span> — <span class="card-category">${escapeHtml(categoryLabelFor(row))}</span></div>
            </div>
            <button class="card-view-btn">Megtekintés</button>
        `;
        card.querySelector('.card-view-btn').addEventListener('click', () => openDetail(row));
        reportCards.appendChild(card);
    });
}

function openDetail(row) {
    detailTarget = row;
    detailHeaderTitle.textContent = `#${row.id} - ${row.title}`;
    detailCategory.textContent = categoryLabelFor(row);
    detailStatus.textContent = row.status === 'claimed' ? `Foglalt: ${row.claimedByName}` : 'Szabad';
    detailDescription.textContent = row.description;

    detailClaimBtn.classList.toggle('hidden', row.status === 'claimed');

    adminPanel.classList.add('hidden');
    adminDetail.classList.remove('hidden');
}

document.getElementById('detailClaimBtn').addEventListener('click', () => {
    if (!detailTarget) return;
    nuiFetch('claimReport', { reportId: detailTarget.id });
    detailTarget = null;
    adminDetail.classList.add('hidden');
});

document.getElementById('detailCloseBtn').addEventListener('click', () => {
    if (!detailTarget) return;
    nuiFetch('closeReport', { reportId: detailTarget.id });
    detailTarget = null;
    adminDetail.classList.add('hidden');
    adminPanel.classList.add('hidden');
});

// ============================================================
// Bezáró gombok (data-close)
// ============================================================
document.querySelectorAll('[data-close]').forEach((btn) => {
    btn.addEventListener('click', () => {
        const target = btn.dataset.close;
        if (target === 'form') { reportForm.classList.add('hidden'); nuiFetch('closeForm', {}); }
        if (target === 'panel') { adminPanel.classList.add('hidden'); nuiFetch('closePanel', {}); }
        if (target === 'detail') { adminDetail.classList.add('hidden'); adminPanel.classList.remove('hidden'); }
    });
});

// ============================================================
// Chat ablak
// ============================================================
function scrollChatToBottom() {
    chatMessages.scrollTop = chatMessages.scrollHeight;
}

function appendMessage(msg) {
    const el = document.createElement('div');
    el.className = `chat-msg ${msg.sender}`;
    el.innerHTML = `<span class="msg-sender">${escapeHtml(msg.senderName)}</span>${escapeHtml(msg.text)}`;
    chatMessages.appendChild(el);
    scrollChatToBottom();
}

function appendSystemMessage(text) {
    const el = document.createElement('div');
    el.className = 'chat-msg system';
    el.textContent = text;
    chatMessages.appendChild(el);
    scrollChatToBottom();
}

function updateUnreadBadge() {
    if (unreadCount > 0 && chatWindow.classList.contains('collapsed')) {
        chatBell.classList.remove('hidden');
        chatBellCount.textContent = unreadCount;
    } else {
        chatBell.classList.add('hidden');
    }
}

function openChatWindow(data) {
    currentReport = { id: data.id, isAdmin: !!data.isAdmin, status: data.status, claimedByName: data.claimedByName };
    unreadCount = 0;

    chatWindow.classList.remove('collapsed', 'hidden');
    updateUnreadBadge();
    document.getElementById('chatFocusHint').classList.remove('hidden');

    chatTitle.textContent = `#${data.id} - ${data.title}`;
    chatCategory.textContent = data.categoryLabel || '';
    chatStatus.textContent = data.status === 'claimed' ? `Foglalt: ${data.claimedByName}` : 'Szabad';

    chatAdminActions.classList.toggle('hidden', !data.isAdmin);

    chatMessages.innerHTML = '';
    (data.messages || []).forEach((m) => appendMessage(m));
}

let dragState = null;
let dragMoved = false;

chatHeaderBar.addEventListener('mousedown', (e) => {
    if (e.target.closest('.chat-bell')) return;
    const rect = chatWindow.getBoundingClientRect();
    dragState = { offsetX: e.clientX - rect.left, offsetY: e.clientY - rect.top };
    dragMoved = false;
});

document.addEventListener('mousemove', (e) => {
    if (!dragState) return;
    dragMoved = true;
    chatWindow.style.left = (e.clientX - dragState.offsetX) + 'px';
    chatWindow.style.top = (e.clientY - dragState.offsetY) + 'px';
    chatWindow.style.right = 'auto';
    chatWindow.style.bottom = 'auto';
});

document.addEventListener('mouseup', () => {
    if (!dragState) return;
    dragState = null;

    if (!dragMoved) {
        // Nem húzás volt, csak kattintás - összecsukás/kinyitás
        chatWindow.classList.toggle('collapsed');
        if (!chatWindow.classList.contains('collapsed')) {
            unreadCount = 0;
            updateUnreadBadge();
        }
    }
});

function sendChatMessage() {
    const text = chatInput.value.trim();
    if (!text || !currentReport) return;
    nuiFetch('sendMessage', { reportId: currentReport.id, text });
    chatInput.value = '';
}

chatSendBtn.addEventListener('click', sendChatMessage);
chatInput.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') sendChatMessage();
});

leaveChatBtn.addEventListener('click', () => {
    if (!currentReport) return;
    nuiFetch('leaveChat', { reportId: currentReport.id });
    chatWindow.classList.add('hidden');
    currentReport = null;
});

document.getElementById('closeChatBtn').addEventListener('click', () => {
    if (!currentReport) return;
    nuiFetch('closeReport', { reportId: currentReport.id });
    chatWindow.classList.add('hidden');
    currentReport = null;
});

chatAdminActions.querySelectorAll('.action-chip[data-action]').forEach((btn) => {
    btn.addEventListener('click', () => {
        if (!currentReport) return;
        nuiFetch('adminAction', { reportId: currentReport.id, action: btn.dataset.action });
    });
});

// ============================================================
// Lua -> JS üzenetek
// ============================================================
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openForm':
            reportForm.classList.remove('hidden');
            break;
        case 'closeForm':
            reportForm.classList.add('hidden');
            break;

        case 'openPanel':
            adminPanel.classList.remove('hidden');
            adminDetail.classList.add('hidden');
            detailTarget = null;
            renderCards(data.reports);
            break;
        case 'updateList':
            renderCards(data.reports);
            if (detailTarget) {
                const updated = data.reports.find((r) => r.id === detailTarget.id);
                if (updated) openDetail(updated);
            }
            break;
        case 'closePanel':
            adminPanel.classList.add('hidden');
            adminDetail.classList.add('hidden');
            break;

        case 'openChat':
            reportForm.classList.add('hidden');
            adminDetail.classList.add('hidden');
            adminPanel.classList.add('hidden');
            detailTarget = null;
            openChatWindow(data.report);
            break;

        case 'newMessage':
            if (currentReport && currentReport.id === data.reportId) {
                appendMessage(data.message);
                if (chatWindow.classList.contains('collapsed')) {
                    unreadCount += 1;
                    updateUnreadBadge();
                }
            }
            break;

        case 'systemMessage':
            if (currentReport && currentReport.id === data.reportId) {
                appendSystemMessage(data.text);
                if (chatWindow.classList.contains('collapsed')) {
                    unreadCount += 1;
                    updateUnreadBadge();
                }
            }
            break;

        case 'statusUpdate':
            if (currentReport && currentReport.id === data.reportId) {
                currentReport.status = data.status;
                currentReport.claimedByName = data.claimedByName;
                chatStatus.textContent = data.status === 'claimed' ? `Foglalt: ${data.claimedByName}` : 'Szabad';
            }
            break;

        case 'closeChat':
            if (currentReport && currentReport.id === data.reportId) {
                appendSystemMessage('A report lezárva.');
                setTimeout(() => {
                    chatWindow.classList.add('hidden');
                    currentReport = null;
                }, 1500);
            }
            break;

        case 'setChatInteractive': {
            const hint = document.getElementById('chatFocusHint');
            hint.classList.toggle('hidden', data.interactive);
            break;
        }
    }
});

// Amíg a NUI-nál van a fókusz (chat interaktív), a billentyűzet is ide jön,
// nem a játékhoz - ezért az ALT-ot itt, a böngészőben is figyelnünk kell,
// hogy ki lehessen kapcsolni ismét (a Lua-oldali RegisterKeyMapping csak a
// BEkapcsolásnál sül el megbízhatóan, amikor még a játéknak van fókusza).
document.addEventListener('keydown', (e) => {
    if (e.key === 'Alt') {
        e.preventDefault();
        nuiFetch('toggleChatFocus', {});
    }
});
