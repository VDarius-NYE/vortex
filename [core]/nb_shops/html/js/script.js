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
const itemsGrid = document.getElementById('itemsGrid');
const cartCol = document.getElementById('cartCol');
const cartList = document.getElementById('cartList');
const cartTotal = document.getElementById('cartTotal');

let state = {
    payload: null,
    cart: {}, // itemKey -> quantity
    paymentMethod: 'cash'
};

function priceText(price) {
    return price === 0 ? 'Ingyenes' : `${price} Ft`;
}

function renderItemsShop() {
    cartCol.classList.remove('hidden');
    itemsGrid.innerHTML = '';

    state.payload.items.forEach((it) => {
        const box = document.createElement('div');
        box.className = 'shop-item';
        box.innerHTML = `
            <div class="item-icon-wrap">
                <img class="item-icon-img" src="nui://nb_inventory/html/assets/items/${it.item.toLowerCase()}.png" alt="${it.label}">
                <i class="item-icon fallback hidden ${it.icon}"></i>
            </div>
            <div class="item-label">${it.label}</div>
            <div class="item-price ${it.price === 0 ? 'free' : ''}">${priceText(it.price)}</div>
            <div class="qty-stepper">
                <button class="qty-minus" type="button">−</button>
                <input type="number" class="qty-input" value="1" min="1">
                <button class="qty-plus" type="button">+</button>
            </div>
            <button class="add-to-cart-btn">Kosárba</button>
        `;

        const img = box.querySelector('.item-icon-img');
        const fallback = box.querySelector('.item-icon.fallback');
        img.addEventListener('error', () => {
            img.classList.add('hidden');
            fallback.classList.remove('hidden');
        });

        const qtyInput = box.querySelector('.qty-input');
        box.querySelector('.qty-minus').addEventListener('click', () => {
            qtyInput.value = Math.max(1, (parseInt(qtyInput.value, 10) || 1) - 1);
        });
        box.querySelector('.qty-plus').addEventListener('click', () => {
            qtyInput.value = (parseInt(qtyInput.value, 10) || 1) + 1;
        });

        box.querySelector('.add-to-cart-btn').addEventListener('click', () => {
            const qty = Math.max(1, parseInt(qtyInput.value, 10) || 1);
            state.cart[it.item] = (state.cart[it.item] || 0) + qty;
            renderCart();
        });

        itemsGrid.appendChild(box);
    });
}

function renderVehicleShop() {
    cartCol.classList.add('hidden');
    itemsGrid.innerHTML = '';

    state.payload.vehicles.forEach((v) => {
        const card = document.createElement('div');
        card.className = 'vehicle-card';
        card.innerHTML = `
            <div class="vehicle-label">${v.label}</div>
            <div class="vehicle-img-wrap">
                <img class="vehicle-img" src="nui://nb_ownvehicles/html/assets/imgs/${v.model.toLowerCase()}.png" alt="${v.label}">
                <i class="fa-solid fa-car vehicle-img-fallback hidden"></i>
            </div>
            <div class="vehicle-price ${v.price === 0 ? 'free' : ''}">${priceText(v.price)}</div>
            <div class="vehicle-buy-actions">
                <select class="pay-select">
                    <option value="cash">Készpénz</option>
                    <option value="card">Bankkártya</option>
                </select>
                <button class="buy-vehicle-btn" data-index="${v.index}" ${v.owned ? 'disabled' : ''}>${v.owned ? 'Megvéve' : 'Vásárlás'}</button>
            </div>
        `;

        const img = card.querySelector('.vehicle-img');
        const fallback = card.querySelector('.vehicle-img-fallback');
        img.addEventListener('error', () => {
            img.classList.add('hidden');
            fallback.classList.remove('hidden');
        });

        if (!v.owned) {
            card.querySelector('.buy-vehicle-btn').addEventListener('click', (e) => {
                const method = card.querySelector('.pay-select').value;
                nuiFetch('buyVehicle', {
                    factionId: state.payload.factionId,
                    shopIndex: state.payload.shopIndex,
                    vehicleIndex: v.index,
                    paymentMethod: method
                });
                e.target.disabled = true;
                e.target.textContent = 'Megvéve';
            });
        }

        itemsGrid.appendChild(card);
    });
}

function findItemDef(itemKey) {
    return state.payload.items.find((i) => i.item === itemKey);
}

function renderCart() {
    cartList.innerHTML = '';
    const keys = Object.keys(state.cart).filter((k) => state.cart[k] > 0);

    if (keys.length === 0) {
        cartList.innerHTML = '<div class="cart-empty">A kosár üres.</div>';
    }

    let total = 0;
    keys.forEach((key) => {
        const def = findItemDef(key);
        if (!def) return;
        const qty = state.cart[key];
        total += def.price * qty;

        const row = document.createElement('div');
        row.className = 'cart-entry';
        row.innerHTML = `
            <span>${def.label} x${qty}</span>
            <button class="cart-entry-remove">✕</button>
        `;
        row.querySelector('.cart-entry-remove').addEventListener('click', () => {
            delete state.cart[key];
            renderCart();
        });
        cartList.appendChild(row);
    });

    cartTotal.textContent = `${total} Ft`;
}

document.querySelectorAll('.payment-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
        state.paymentMethod = btn.dataset.method;
        document.querySelectorAll('.payment-btn').forEach((b) => b.classList.toggle('active', b === btn));
    });
});

document.getElementById('checkoutBtn').addEventListener('click', () => {
    const cart = Object.keys(state.cart)
        .filter((k) => state.cart[k] > 0)
        .map((k) => ({ item: k, quantity: state.cart[k] }));

    if (cart.length === 0) return;

    nuiFetch('checkout', {
        shopType: state.payload.shopType,
        factionId: state.payload.factionId,
        shopIndex: state.payload.shopIndex,
        cart,
        paymentMethod: state.paymentMethod
    });
});

document.getElementById('closeBtn').addEventListener('click', () => {
    nuiFetch('closeShop', {});
    app.classList.add('hidden');
});

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        nuiFetch('closeShop', {});
        app.classList.add('hidden');
    }
});

window.addEventListener('message', (event) => {
    const data = event.data;

    if (data.action === 'open') {
        state.payload = data.payload;
        state.cart = {};
        document.getElementById('shopTitle').textContent = state.payload.title || 'BOLT';

        if (state.payload.shopType === 'vehicle') {
            renderVehicleShop();
        } else {
            renderItemsShop();
            renderCart();
        }

        app.classList.remove('hidden');
    } else if (data.action === 'close') {
        app.classList.add('hidden');
    } else if (data.action === 'checkoutDone') {
        state.cart = {};
        renderCart();
    } else if (data.action === 'vehiclePurchaseFailed') {
        const btn = document.querySelector(`.buy-vehicle-btn[data-index="${data.vehicleIndex}"]`);
        if (btn) {
            btn.disabled = false;
            btn.textContent = 'Vásárlás';
        }
    }
});
