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
const garageList = document.getElementById('garageList');
let currentPayload = null;

function render(payload) {
    currentPayload = payload;
    document.getElementById('garageTitle').textContent = `GARÁZS — ${payload.garageName || ''}`;
    garageList.innerHTML = '';

    if (!payload.vehicles || payload.vehicles.length === 0) {
        garageList.innerHTML = '<div class="garage-empty">Még nincs saját járműved. Vásárolj egyet egy vehicle shopban!</div>';
        return;
    }

    payload.vehicles.forEach((v) => {
        const isOut = v.spawned == 1;
        const row = document.createElement('div');
        row.className = 'vehicle-entry';
        row.innerHTML = `
            <div class="vehicle-info">
                <div class="vehicle-name">${v.label} (${v.plate})</div>
            </div>
            <div class="vehicle-img-wrap">
                <img class="vehicle-img" src="nui://nb_ownvehicles/html/assets/imgs/${v.model.toLowerCase()}.png" alt="${v.label}">
                <i class="fa-solid fa-car vehicle-img-fallback hidden"></i>
            </div>
            <span class="vehicle-status ${isOut ? 'out' : 'stored'}">${isOut ? 'Kint van' : 'Tárolva'}</span>
            <button class="spawn-btn" ${isOut ? 'disabled' : ''}>Lehívás</button>
        `;

        const img = row.querySelector('.vehicle-img');
        const fallback = row.querySelector('.vehicle-img-fallback');
        img.addEventListener('error', () => {
            img.classList.add('hidden');
            fallback.classList.remove('hidden');
        });

        row.querySelector('.spawn-btn').addEventListener('click', () => {
            if (isOut) return;
            nuiFetch('spawnVehicle', {
                vehicleRowId: v.id,
                factionId: payload.factionId,
                garageIndex: payload.garageIndex
            });
        });
        garageList.appendChild(row);
    });
}

document.getElementById('closeBtn').addEventListener('click', () => {
    nuiFetch('closeGarage', {});
    app.classList.add('hidden');
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        nuiFetch('closeGarage', {});
        app.classList.add('hidden');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;
    if (data.action === 'open') {
        render(data.payload);
        app.classList.remove('hidden');
    } else if (data.action === 'close') {
        app.classList.add('hidden');
    }
});
