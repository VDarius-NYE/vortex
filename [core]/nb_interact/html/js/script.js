const container = document.getElementById('container');
const nodes = {}; // id -> element

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text == null ? '' : String(text);
    return div.innerHTML;
}

function render(points) {
    const activeIds = new Set(points.map((p) => p.id));

    // Eltűnt pontok törlése
    Object.keys(nodes).forEach((id) => {
        if (!activeIds.has(id)) {
            nodes[id].remove();
            delete nodes[id];
        }
    });

    points.forEach((p) => {
        let el = nodes[p.id];
        if (!el) {
            el = document.createElement('div');
            el.className = 'interact-point';
            container.appendChild(el);
            nodes[p.id] = el;
        }

        el.style.left = (p.x * 100) + '%';
        el.style.top = (p.y * 100) + '%';

        if (p.near) {
            el.innerHTML = `<div class="interact-near"><div class="interact-frame"><div class="corner tl"></div><div class="corner tr"></div><div class="corner bl"></div><div class="corner br"></div><div class="key-box">E</div></div><div class="interact-label">${escapeHtml(p.label)}</div></div>`;
        } else {
            el.innerHTML = `<div class="interact-dot-wrap"><div class="interact-ring"></div><div class="interact-dot"></div></div>`;
        }
    });
}

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'update') {
        render(data.points || []);
    }
});
