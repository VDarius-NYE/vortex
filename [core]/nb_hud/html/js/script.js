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
const visibilityList = document.getElementById('visibilityList');

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
    if (el.alwaysVisible) return true;
    return value <= el.threshold;
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

function renderElementContent(def, value) {
    const { inner } = elementNodes[def.key];
    const style = state.settings.style;
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
        const posSettings = state.settings.elements[def.key];
        wrap.style.left = posSettings.xPercent + '%';
        wrap.style.top = posSettings.yPercent + '%';
        wrap.dataset.style = state.settings.style;

        const value = Math.round(state.stats[def.key] ?? 100);
        renderElementContent(def, value);

        const visible = isVisible(def.key, value);
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
// Szerkesztő panel
// ============================================================
function renderEditorPanel() {
    document.querySelectorAll('.style-btn').forEach((btn) => {
        btn.classList.toggle('active', btn.dataset.style === state.settings.style);
    });

    visibilityList.innerHTML = '';
    state.elementDefs.forEach((def) => {
        const elSettings = state.settings.elements[def.key];

        const item = document.createElement('div');
        item.className = 'visibility-item';

        const name = document.createElement('div');
        name.className = 'vis-name';
        name.innerHTML = `<i class="${def.icon}"></i> ${def.label}`;
        item.appendChild(name);

        const controls = document.createElement('div');
        controls.className = 'vis-controls';

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
        visibilityList.appendChild(item);
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
