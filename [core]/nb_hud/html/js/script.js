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

const hudContainer = document.getElementById('hudContainer');
const editorOverlay = document.getElementById('editorOverlay');
const editorPanelEl = document.querySelector('.editor-panel');
const editorDragHandle = document.getElementById('editorDragHandle');
const visListVital = document.getElementById('visListVital');
const visListInfo = document.getElementById('visListInfo');
const visListOther = document.getElementById('visListOther');

function getCategoryList(category) {
    if (category === 'vital') return visListVital;
    if (category === 'info') return visListInfo;
    return visListOther; // killfeed és bármi jövőbeli egyéb
}

let state = {
    settings: null,
    stats: { health: 100, armor: 0, hunger: 100, thirst: 100, stamina: 100 },
    elementDefs: [],
    editMode: false
};

const elementNodes = {}; // key -> { wrap, inner }

function stateClass(value) {
    if (value > 60) return 'state-good';
    if (value > 30) return 'state-warn';
    return 'state-danger';
}

function isVisible(key, value) {
    const el = state.settings.elements[key];
    if (!el) return true;
    if (state.editMode) return true; // szerkesztés közben minden látszik

    const def = state.elementDefs.find((d) => d.key === key);

    if (def && def.category === 'killfeed') {
        return false; // ide már csak akkor jutunk, ha NEM szerkesztés mód - a placeholder ilyenkor mindig rejtve, a valódi killfeedet az nb_killfeed rajzolja
    }

    if (def && def.category === 'info') {
        return !!el.alwaysVisible; // info elemeknél nincs küszöb, csak egyszerű be/ki
    }

    if (el.alwaysVisible) return true;
    return value <= el.threshold;
}

function formatValue(def, raw) {
    if (raw == null) return '-';

    if (def.format === 'currency') {
        const num = Number(raw) || 0;
        return num.toLocaleString('hu-HU') + ' Ft';
    }
    if (def.format === 'number') {
        return String(Math.round(Number(raw) || 0));
    }
    if (def.format === 'duration') {
        const mins = Math.round(Number(raw) || 0);
        const h = Math.floor(mins / 60);
        const m = mins % 60;
        return h > 0 ? `${h}ó ${m}p` : `${m}p`;
    }
    return String(raw); // 'text' vagy egyéb
}

function buildRadialSvg() {
    const r = 21;
    const c = 2 * Math.PI * r;
    return { circumference: c, radius: r };
}

function createElementDom(def) {
    const wrap = document.createElement('div');
    wrap.className = 'hud-element';
    wrap.dataset.key = def.key;

    const inner = document.createElement('div');
    inner.className = 'hud-inner';
    wrap.appendChild(inner);

    hudContainer.appendChild(wrap);
    elementNodes[def.key] = { wrap, inner };
    return { wrap, inner };
}

function renderElementContent(def, rawValue) {
    const { inner } = elementNodes[def.key];

    if (def.category === 'killfeed') {
        inner.className = 'hud-inner killfeed-placeholder';
        inner.innerHTML = `
            <div class="killfeed-ph-header"><i class="${def.icon}"></i> ${def.label}</div>
            <div class="killfeed-ph-row"><span class="ph-killer">TesztOlo</span> megölte <span class="ph-victim">TesztAldozat</span> játékost.</div>
        `;
        return;
    }

    if (def.category === 'info') {
        inner.className = 'hud-inner info-inner';
        inner.innerHTML = `
            <span class="hud-icon"><i class="${def.icon}"></i></span>
            <span class="info-label">${def.label}</span>
            <span class="info-value">${formatValue(def, rawValue)}</span>
        `;
        return;
    }

    const style = state.settings.style;
    const value = Math.round(Number(rawValue) || 0);
    const cls = stateClass(value);
    inner.className = 'hud-inner ' + cls;

    if (style === 'bar') {
        inner.innerHTML = `
            <span class="hud-icon"><i class="${def.icon}"></i></span>
            <div class="hud-bar-track"><div class="hud-bar-fill" style="width:${value}%"></div></div>
            <span class="hud-number">${value}%</span>
        `;
    } else if (style === 'radial') {
        const { circumference, radius } = buildRadialSvg();
        const offset = circumference - (value / 100) * circumference;
        inner.innerHTML = `
            <div class="radial-wrap">
                <svg width="52" height="52">
                    <circle class="radial-track" cx="26" cy="26" r="${radius}"></circle>
                    <circle class="radial-fill" cx="26" cy="26" r="${radius}"
                        stroke-dasharray="${circumference}" stroke-dashoffset="${offset}"></circle>
                </svg>
                <div class="radial-center">
                    <span class="hud-icon"><i class="${def.icon}"></i></span>
                </div>
            </div>
            <span class="radial-percent">${value}%</span>
        `;
    } else { // numeric
        inner.innerHTML = `
            <span class="hud-icon"><i class="${def.icon}"></i></span>
            <span class="hud-number">${value}%</span>
        `;
    }
}

function renderAll() {
    if (!state.settings) return;

    state.elementDefs.forEach((def) => {
        if (!elementNodes[def.key]) createElementDom(def);

        const { wrap } = elementNodes[def.key];
        const posSettings = state.settings.elements[def.key] || { xPercent: 3, yPercent: 50, alwaysVisible: false, threshold: 100 };
        wrap.style.left = posSettings.xPercent + '%';
        wrap.style.top = posSettings.yPercent + '%';
        wrap.dataset.style = def.category === 'info' ? 'info' : state.settings.style;

        const rawValue = state.stats[def.key];
        renderElementContent(def, rawValue);

        const checkValue = def.category === 'info' ? rawValue : Math.round(Number(rawValue) || 0);
        const visible = isVisible(def.key, checkValue);
        wrap.classList.toggle('faded', !visible);
        wrap.classList.toggle('editing', state.editMode);
    });
}

// ============================================================
// Drag & drop (csak szerkesztő módban aktív)
// ============================================================
let dragging = null;

function onMouseDown(e) {
    if (!state.editMode) return;
    const wrap = e.currentTarget;
    dragging = {
        key: wrap.dataset.key,
        wrap,
        offsetX: e.clientX,
        offsetY: e.clientY,
        startXPercent: state.settings.elements[wrap.dataset.key].xPercent,
        startYPercent: state.settings.elements[wrap.dataset.key].yPercent
    };
    e.preventDefault();
}

document.addEventListener('mousemove', (e) => {
    if (!dragging) return;
    const dx = ((e.clientX - dragging.offsetX) / window.innerWidth) * 100;
    const dy = ((e.clientY - dragging.offsetY) / window.innerHeight) * 100;

    let newX = Math.max(0, Math.min(96, dragging.startXPercent + dx));
    let newY = Math.max(2, Math.min(98, dragging.startYPercent + dy));

    state.settings.elements[dragging.key].xPercent = newX;
    state.settings.elements[dragging.key].yPercent = newY;

    dragging.wrap.style.left = newX + '%';
    dragging.wrap.style.top = newY + '%';
});

document.addEventListener('mouseup', () => {
    dragging = null;
});

// ============================================================
// Maga a szerkesztő PANEL is mozgatható (a fejlécénél fogva) - session-en
// belül, nem perzisztens (mindig a jobb-közép alapértelmezettel nyílik meg).
// ============================================================
let dragPanel = null;

editorDragHandle.addEventListener('mousedown', (e) => {
    const rect = editorPanelEl.getBoundingClientRect();
    dragPanel = { offsetX: e.clientX - rect.left, offsetY: e.clientY - rect.top };
});

document.addEventListener('mousemove', (e) => {
    if (!dragPanel) return;
    editorPanelEl.style.left = (e.clientX - dragPanel.offsetX) + 'px';
    editorPanelEl.style.top = (e.clientY - dragPanel.offsetY) + 'px';
    editorPanelEl.style.right = 'auto';
    editorPanelEl.style.transform = 'none';
});

document.addEventListener('mouseup', () => {
    dragPanel = null;
});

// ============================================================
// Szerkesztő panel
// ============================================================
function renderEditorPanel() {
    document.querySelectorAll('.style-btn').forEach((btn) => {
        btn.classList.toggle('active', btn.dataset.style === state.settings.style);
    });

    visListVital.innerHTML = '';
    visListInfo.innerHTML = '';
    visListOther.innerHTML = '';

    state.elementDefs.forEach((def) => {
        const elSettings = state.settings.elements[def.key] || { xPercent: 3, yPercent: 50, alwaysVisible: false, threshold: 100 };
        state.settings.elements[def.key] = elSettings;

        const item = document.createElement('div');
        item.className = 'visibility-item';

        const name = document.createElement('div');
        name.className = 'vis-name';
        name.innerHTML = `<i class="${def.icon}"></i> ${def.label}`;
        item.appendChild(name);

        const controls = document.createElement('div');
        controls.className = 'vis-controls';

        if (def.category === 'info' || def.category === 'killfeed') {
            // Info/killfeed elemeknél nincs küszöb-fogalom, csak egyszerű be/ki kapcsoló
            const label = document.createElement('label');
            label.className = 'toggle-label';
            const checkbox = document.createElement('input');
            checkbox.type = 'checkbox';
            checkbox.checked = !!elSettings.alwaysVisible;
            checkbox.addEventListener('change', () => {
                elSettings.alwaysVisible = checkbox.checked;
                renderAll();
            });
            label.appendChild(checkbox);
            label.appendChild(document.createTextNode(' Megjelenítés'));
            controls.appendChild(label);

            item.appendChild(controls);
            getCategoryList(def.category).appendChild(item);
            return;
        }

        const select = document.createElement('select');
        const optAlways = document.createElement('option');
        optAlways.value = 'always';
        optAlways.textContent = 'Mindig látható';
        const optThreshold = document.createElement('option');
        optThreshold.value = 'threshold';
        optThreshold.textContent = 'Csak X% alatt';
        select.appendChild(optAlways);
        select.appendChild(optThreshold);
        select.value = elSettings.alwaysVisible ? 'always' : 'threshold';

        const thresholdInput = document.createElement('input');
        thresholdInput.type = 'number';
        thresholdInput.min = '0';
        thresholdInput.max = '100';
        thresholdInput.value = elSettings.threshold;
        thresholdInput.style.display = elSettings.alwaysVisible ? 'none' : 'inline-block';

        select.addEventListener('change', () => {
            elSettings.alwaysVisible = select.value === 'always';
            thresholdInput.style.display = elSettings.alwaysVisible ? 'none' : 'inline-block';
            renderAll();
        });

        thresholdInput.addEventListener('input', () => {
            elSettings.threshold = parseInt(thresholdInput.value, 10) || 0;
            renderAll();
        });

        controls.appendChild(select);
        controls.appendChild(thresholdInput);
        controls.appendChild(document.createTextNode('%'));

        item.appendChild(controls);
        getCategoryList(def.category).appendChild(item);
    });
}

document.querySelectorAll('.style-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
        state.settings.style = btn.dataset.style;
        renderEditorPanel();
        renderAll();
    });
});

document.getElementById('saveEditorBtn').addEventListener('click', () => {
    nuiFetch('saveSettings', { settings: state.settings });
});

document.getElementById('resetEditorBtn').addEventListener('click', () => {
    nuiFetch('resetSettings', {});
});

document.getElementById('closeEditorBtn').addEventListener('click', () => {
    nuiFetch('closeEditor', {});
});

// ============================================================
// Lua -> JS üzenetek
// ============================================================
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'init') {
        state.settings = data.settings;
        state.stats = data.stats;
        state.elementDefs = data.elementDefs;
        renderAll();
        nuiFetch('hudReady', {});
    } else if (data.action === 'updateStats') {
        state.stats = data.stats;
        renderAll();
    } else if (data.action === 'updateSettings') {
        state.settings = data.settings;
        renderAll();
        if (state.editMode) renderEditorPanel();
    } else if (data.action === 'enterEditMode') {
        state.editMode = true;
        state.settings = data.settings;
        state.elementDefs = data.elementDefs;
        editorOverlay.classList.remove('hidden');
        renderAll();
        renderEditorPanel();

        // Drag figyelők bekötése minden elemre (csak most, hogy léteznek a node-ok)
        Object.values(elementNodes).forEach(({ wrap }) => {
            wrap.removeEventListener('mousedown', onMouseDown);
            wrap.addEventListener('mousedown', onMouseDown);
        });
    } else if (data.action === 'exitEditMode') {
        state.editMode = false;
        editorOverlay.classList.add('hidden');
        renderAll();
    }
});
