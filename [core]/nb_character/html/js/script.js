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

let state = {
    mode: 'create',
    appearance: null,
    limits: null,
    overlayDefs: []
};

const CLOTHING_LABELS = {
    3: 'Alsó felsőtest', 4: 'Nadrág', 5: 'Táska', 6: 'Cipő',
    7: 'Sál / lánc', 8: 'Felső (alap póló)', 9: 'Testpáncél',
    10: 'Extra ruhadarab', 11: 'Felsőruha / kabát'
};

const PROP_LABELS = {
    0: 'Kalap / sisak', 1: 'Szemüveg', 2: 'Fülbevaló', 6: 'Óra', 7: 'Karkötő'
};

const FACE_FEATURE_NAMES = [
    'Orr szélesség', 'Orr magasság (hegy)', 'Orr hossz (hegy)', 'Orr csont magasság',
    'Orr hegy lejtés', 'Orr csont csavarás', 'Szemöldök magasság', 'Szemöldök mélység',
    'Arccsont magasság', 'Arccsont szélesség', 'Arc szélesség', 'Szem nyílás',
    'Ajak vastagság', 'Állcsont szélesség', 'Állcsont hossz', 'Áll lejtés',
    'Áll hossz', 'Áll méret', 'Áll lyuk', 'Nyak vastagság'
];

// ---------- Segédfüggvények nested mező kezeléshez (pl. "headBlend.shapeFirst") ----------
function getField(path) {
    return path.split('.').reduce((obj, key) => (obj ? obj[key] : undefined), state.appearance);
}

function setField(path, value) {
    const keys = path.split('.');
    let obj = state.appearance;
    for (let i = 0; i < keys.length - 1; i++) {
        obj = obj[keys[i]];
    }
    obj[keys[keys.length - 1]] = value;
}

let sendTimeout = null;
function sendUpdate(changed) {
    clearTimeout(sendTimeout);
    sendTimeout = setTimeout(() => {
        nuiFetch('update', { appearance: state.appearance, changed });
    }, 30);
}

// ---------- Stepper (lépegető) mezők ----------
function buildStepper(container, path, min, max, wrap = true, changedHint = null) {
    container.innerHTML = '';
    container.dataset.field = path;

    const minus = document.createElement('button');
    minus.textContent = '−';
    const valueEl = document.createElement('div');
    valueEl.className = 'stepper-value';
    const plus = document.createElement('button');
    plus.textContent = '+';

    function refresh() {
        valueEl.textContent = getField(path);
    }

    function step(dir) {
        let value = getField(path) + dir;
        if (value > max) value = wrap ? min : max;
        if (value < min) value = wrap ? max : min;
        setField(path, value);
        refresh();
        sendUpdate(changedHint);
    }

    minus.addEventListener('click', () => step(-1));
    plus.addEventListener('click', () => step(1));

    container.appendChild(minus);
    container.appendChild(valueEl);
    container.appendChild(plus);
    refresh();
}

function wireAllSteppers(root) {
    root.querySelectorAll('.stepper[data-field]').forEach((el) => {
        const path = el.dataset.field;
        const max = parseInt(el.dataset.max || '0', 10);
        buildStepper(el, path, 0, max, false, 'headBlend');
    });
}

function wireAllSliders(root) {
    root.querySelectorAll('input[type="range"][data-field]').forEach((el) => {
        const path = el.dataset.field;
        el.value = getField(path);
        el.addEventListener('input', () => {
            setField(path, parseFloat(el.value));
            sendUpdate('headBlend');
        });
    });
}

// ---------- Arc jellemzők (20 csúszka -1..1) ----------
function renderFeatures() {
    const list = document.getElementById('featuresList');
    list.innerHTML = '';

    for (let i = 0; i < 20; i++) {
        const wrap = document.createElement('div');
        wrap.className = 'slider-row';

        const label = document.createElement('label');
        label.textContent = FACE_FEATURE_NAMES[i] || `Jellemző ${i + 1}`;

        const input = document.createElement('input');
        input.type = 'range';
        input.min = '-1';
        input.max = '1';
        input.step = '0.02';
        input.value = state.appearance.faceFeatures[i];

        input.addEventListener('input', () => {
            state.appearance.faceFeatures[i] = parseFloat(input.value);
            sendUpdate(`faceFeature:${i}`);
        });

        wrap.appendChild(label);
        wrap.appendChild(input);
        list.appendChild(wrap);
    }
}

// ---------- Overlay-ok (smink, szakáll, jegyek stb.) ----------
function renderOverlays() {
    const list = document.getElementById('overlaysList');
    list.innerHTML = '';

    state.overlayDefs.forEach((def) => {
        const key = String(def.id);
        const data = state.appearance.headOverlays[key];

        const item = document.createElement('div');
        item.className = 'overlay-item';

        const header = document.createElement('div');
        header.className = 'overlay-header';
        header.textContent = def.name;
        item.appendChild(header);

        const controls = document.createElement('div');
        controls.className = 'overlay-controls';

        // Index stepper (-1 = kikapcsolva)
        const indexWrap = document.createElement('div');
        const indexLabel = document.createElement('span');
        indexLabel.className = 'mini-label';
        indexLabel.textContent = 'Típus';
        const indexStepper = document.createElement('div');
        indexStepper.className = 'stepper';
        indexWrap.appendChild(indexLabel);
        indexWrap.appendChild(indexStepper);
        controls.appendChild(indexWrap);

        buildStepper(indexStepper, `headOverlays.${key}.index`, -1, 29, false, `overlay:${key}`);

        // Opacity slider
        const opacityWrap = document.createElement('div');
        opacityWrap.style.minWidth = '160px';
        const opacityLabel = document.createElement('span');
        opacityLabel.className = 'mini-label';
        opacityLabel.textContent = 'Erősség';
        const opacitySlider = document.createElement('input');
        opacitySlider.type = 'range';
        opacitySlider.min = '0';
        opacitySlider.max = '1';
        opacitySlider.step = '0.02';
        opacitySlider.value = data.opacity;
        opacitySlider.addEventListener('input', () => {
            data.opacity = parseFloat(opacitySlider.value);
            sendUpdate(`overlay:${key}`);
        });
        opacityWrap.appendChild(opacityLabel);
        opacityWrap.appendChild(opacitySlider);
        controls.appendChild(opacityWrap);

        if (def.hasColor) {
            const colorWrap = document.createElement('div');
            const colorLabel = document.createElement('span');
            colorLabel.className = 'mini-label';
            colorLabel.textContent = 'Szín';
            const colorStepper = document.createElement('div');
            colorStepper.className = 'stepper';
            colorWrap.appendChild(colorLabel);
            colorWrap.appendChild(colorStepper);
            controls.appendChild(colorWrap);

            buildStepper(colorStepper, `headOverlays.${key}.colorIndex`, 0, 63, true, `overlay:${key}`);
        }

        item.appendChild(controls);
        list.appendChild(item);
    });
}

// ---------- Ruházat / kiegészítők (közös logika) ----------
function renderComponentList(containerId, slots, limitsObj, labels, appearanceKey, allowNone) {
    const list = document.getElementById(containerId);
    list.innerHTML = '';

    slots.forEach((slotKey) => {
        const slotLimits = limitsObj[slotKey] || { drawableCount: 1, textureCounts: { '0': 1 } };
        const data = state.appearance[appearanceKey][slotKey];

        const item = document.createElement('div');
        item.className = 'component-item';

        const name = document.createElement('div');
        name.className = 'component-name';
        name.textContent = labels[slotKey] || `Slot ${slotKey}`;
        item.appendChild(name);

        const steppers = document.createElement('div');
        steppers.className = 'component-steppers';

        const drawableWrap = document.createElement('div');
        const drawableLabel = document.createElement('span');
        drawableLabel.className = 'mini-label';
        drawableLabel.textContent = 'Típus';
        const drawableStepper = document.createElement('div');
        drawableStepper.className = 'stepper';
        drawableWrap.appendChild(drawableLabel);
        drawableWrap.appendChild(drawableStepper);
        steppers.appendChild(drawableWrap);

        const minDrawable = allowNone ? -1 : 0;
        const maxDrawable = Math.max(slotLimits.drawableCount - 1, 0);

        const textureWrap = document.createElement('div');
        const textureLabel = document.createElement('span');
        textureLabel.className = 'mini-label';
        textureLabel.textContent = 'Szín/textúra';
        const textureStepper = document.createElement('div');
        textureStepper.className = 'stepper';
        textureWrap.appendChild(textureLabel);
        textureWrap.appendChild(textureStepper);
        steppers.appendChild(textureWrap);

        function refreshTextureStepper() {
            const drawable = data.drawable;
            const maxTexture = drawable >= 0
                ? Math.max((slotLimits.textureCounts[String(drawable)] || 1) - 1, 0)
                : 0;
            buildCustomStepper(textureStepper, () => data.texture, (v) => { data.texture = v; sendUpdate(`${appearanceKey === 'components' ? 'component' : 'prop'}:${slotKey}`); }, 0, maxTexture);
        }

        buildCustomStepper(drawableStepper, () => data.drawable, (v) => {
            data.drawable = v;
            if (v < 0) data.texture = 0;
            refreshTextureStepper();
            sendUpdate(`${appearanceKey === 'components' ? 'component' : 'prop'}:${slotKey}`);
        }, minDrawable, maxDrawable);

        refreshTextureStepper();

        item.appendChild(steppers);
        list.appendChild(item);
    });
}

// Általánosabb stepper builder, ami getter/setter függvényt kap (nem csak state útvonalat)
function buildCustomStepper(container, getter, setter, min, max) {
    container.innerHTML = '';

    const minus = document.createElement('button');
    minus.textContent = '−';
    const valueEl = document.createElement('div');
    valueEl.className = 'stepper-value';
    const plus = document.createElement('button');
    plus.textContent = '+';

    function refresh() {
        valueEl.textContent = getter();
    }

    function step(dir) {
        let value = getter() + dir;
        if (value > max) value = min;
        if (value < min) value = max;
        setter(value);
        refresh();
    }

    minus.addEventListener('click', () => step(-1));
    plus.addEventListener('click', () => step(1));

    container.appendChild(minus);
    container.appendChild(valueEl);
    container.appendChild(plus);
    refresh();
}

// ---------- Teljes render ----------
function renderAll() {
    // Modell gombok kiemelése
    document.querySelectorAll('.model-btn').forEach((btn) => {
        btn.classList.toggle('active', btn.dataset.model === state.appearance.model);
    });

    // Arc alak steppers + sliders
    wireAllSteppers(document.querySelector('[data-panel="faceshape"]'));
    wireAllSliders(document.querySelector('[data-panel="faceshape"]'));

    renderFeatures();
    renderOverlays();

    // Haj
    const hairStyleStepper = document.querySelector('[data-field="hair.style"]');
    buildCustomStepper(hairStyleStepper,
        () => state.appearance.hair.style,
        (v) => { state.appearance.hair.style = v; sendUpdate('hair'); },
        0, Math.max((state.limits.hairStyleCount || 1) - 1, 0)
    );
    const hairColorStepper = document.querySelector('[data-field="hair.color"]');
    buildCustomStepper(hairColorStepper,
        () => state.appearance.hair.color,
        (v) => { state.appearance.hair.color = v; sendUpdate('hair'); },
        0, 63
    );
    const hairHighlightStepper = document.querySelector('[data-field="hair.highlight"]');
    buildCustomStepper(hairHighlightStepper,
        () => state.appearance.hair.highlight,
        (v) => { state.appearance.hair.highlight = v; sendUpdate('hair'); },
        0, 63
    );

    // Szem
    const eyeStepper = document.querySelector('[data-field="eyeColor"]');
    buildCustomStepper(eyeStepper,
        () => state.appearance.eyeColor,
        (v) => { state.appearance.eyeColor = v; sendUpdate('eyeColor'); },
        0, 31
    );

    // Ruházat / kiegészítők
    renderComponentList('clothesList', Object.keys(state.limits.components), state.limits.components, CLOTHING_LABELS, 'components', false);
    renderComponentList('propsList', Object.keys(state.limits.props), state.limits.props, PROP_LABELS, 'props', true);
}

const FULL_BODY_TABS = ['model', 'clothes', 'props'];

// ---------- Tabok ----------
document.querySelectorAll('.tab-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
        document.querySelectorAll('.tab-btn').forEach((b) => b.classList.remove('active'));
        document.querySelectorAll('.tab-panel').forEach((p) => p.classList.remove('active'));
        btn.classList.add('active');
        document.querySelector(`[data-panel="${btn.dataset.tab}"]`).classList.add('active');

        const mode = FULL_BODY_TABS.includes(btn.dataset.tab) ? 'body' : 'face';
        nuiFetch('setCameraMode', { mode });
    });
});

// ---------- Modell váltás ----------
document.querySelectorAll('.model-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
        nuiFetch('changeModel', { model: btn.dataset.model }).then((resp) => {
            state.appearance = resp.appearance;
            state.limits = resp.limits;
            renderAll();
        });
    });
});

// ---------- Mentés / Mégse ----------
document.getElementById('saveBtn').addEventListener('click', () => {
    nuiFetch('save', { model: state.appearance.model, appearance: state.appearance });
});

document.getElementById('cancelBtn').addEventListener('click', () => {
    nuiFetch('cancel', {});
});

// ---------- Kamera forgatás A/D billentyűvel (JS oldalon figyeljük, a Lua
// csak egy irány-jelzést kap, semmilyen input nem jut el a karakterhez) ----------
let currentRotateDir = 'none';

function setRotateDir(dir) {
    if (dir === currentRotateDir) return;
    currentRotateDir = dir;
    nuiFetch('cameraRotate', { direction: dir });
}

document.addEventListener('keydown', (e) => {
    if (app.classList.contains('hidden')) return;
    const key = e.key.toLowerCase();
    if (key === 'a') setRotateDir('left');
    else if (key === 'd') setRotateDir('right');
});

document.addEventListener('keyup', (e) => {
    const key = e.key.toLowerCase();
    if ((key === 'a' && currentRotateDir === 'left') || (key === 'd' && currentRotateDir === 'right')) {
        setRotateDir('none');
    }
});

// Ha az ablak elveszti a fókuszt (pl. alt-tab) miközben A/D lenyomva volt,
// ne ragadjon be a forgatás
window.addEventListener('blur', () => setRotateDir('none'));

// ---------- Lua -> JS üzenetek ----------
window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        state.mode = data.mode;
        state.appearance = data.appearance;
        state.limits = data.limits;
        state.overlayDefs = data.overlayDefs || [];
        currentRotateDir = 'none';

        document.getElementById('cancelBtn').classList.toggle('hidden', state.mode !== 'edit');

        app.classList.remove('hidden');
        renderAll();

        nuiFetch('creatorReady', {});
    } else if (data.action === 'close') {
        app.classList.add('hidden');
        currentRotateDir = 'none';
    }
});
