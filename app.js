import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const SUPABASE_URL = 'https://weedtysnxjqqbficwgrx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlZWR0eXNueGpxcWJmaWN3Z3J4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk1ODYwODMsImV4cCI6MjEwNTE2MjA4M30.9QYjIfbenGYsXYs5rGcOn5ATjUgGv8fE4qVB4dejqXU';

export const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

const app = document.getElementById('app');

// ---------- helpers ----------
const fmt = (n) => `$${Number(n || 0).toFixed(2)}`;
const fmtDate = (d) => new Date(d).toLocaleDateString('es-PR', { year: 'numeric', month: 'short', day: 'numeric' });
const fmtDateTime = (d) => new Date(d).toLocaleString('es-PR', { dateStyle: 'medium', timeStyle: 'short' });
const todayStartISO = () => { const d = new Date(); d.setHours(0, 0, 0, 0); return d.toISOString(); };
const todayDateStr = () => new Date().toISOString().slice(0, 10);
const uid = () => Math.random().toString(36).slice(2, 10);
const esc = (s) => (s ?? '').toString().replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

const PAYMENT_LABELS = { cash: 'Efectivo', card: 'Tarjeta', ath_movil: 'ATH Móvil', other: 'Otro' };
const CHANNEL_LABELS = { store: 'Tienda', doordash: 'DoorDash', other: 'Otro' };

function toast(msg, kind = 'pink') {
  const el = document.createElement('div');
  const colors = { pink: 'bg-blush-500', mint: 'bg-mint-500', red: 'bg-rose-500' };
  el.className = `fixed bottom-5 left-1/2 -translate-x-1/2 ${colors[kind] || colors.pink} text-white px-5 py-3 rounded-2xl shadow-lg z-[100] font-semibold text-sm`;
  el.textContent = msg;
  document.body.appendChild(el);
  setTimeout(() => el.remove(), 3200);
}

// ---------- auth state ----------
let currentSession = null;

async function initAuth() {
  const { data } = await supabase.auth.getSession();
  currentSession = data.session;
  supabase.auth.onAuthStateChange((_event, session) => {
    currentSession = session;
    render();
  });
}

// ---------- router ----------
const routes = {
  '': pageDashboard,
  dashboard: pageDashboard,
  venta: pageVenta,
  clientes: pageClientes,
  historial: pageHistorial,
  recompensas: pageRecompensas,
  recibos: pageRecibos,
  contabilidad: pageContabilidad,
};

function currentRoute() {
  const hash = location.hash.replace(/^#\/?/, '');
  const [route, param] = hash.split('/');
  return { route: route || 'dashboard', param };
}

window.addEventListener('hashchange', render);

async function render() {
  if (!currentSession) {
    renderLogin();
    return;
  }
  renderShell();
  const outlet = document.getElementById('outlet');
  const { route, param } = currentRoute();

  if (route === 'recibo' && param) {
    await pageReciboDetalle(outlet, param);
    return;
  }
  const page = routes[route] || pageDashboard;
  await page(outlet);
  highlightNav(route);
}

function highlightNav(route) {
  document.querySelectorAll('.nav-link').forEach((a) => {
    a.classList.toggle('active', a.dataset.route === route);
  });
}

// ---------- shell / layout ----------
function renderShell() {
  const email = currentSession?.user?.email || '';
  app.innerHTML = `
    <div class="min-h-screen flex flex-col">
      <header class="no-print sticky top-0 z-40 bg-white/90 backdrop-blur border-b border-blush-100">
        <div class="max-w-7xl mx-auto px-4 py-3 flex items-center justify-between gap-4">
          <div class="flex items-center gap-2">
            <span class="text-2xl">🍓</span>
            <div class="leading-tight">
              <div class="font-heading font-bold text-blush-600 text-lg">B Fresas Lovers</div>
              <div class="text-[11px] text-slate-400 -mt-1">hecho para los verdaderos lovers.</div>
            </div>
          </div>
          <nav class="hidden md:flex items-center gap-1 overflow-x-auto">
            <a href="#/dashboard" data-route="dashboard" class="nav-link">Dashboard</a>
            <a href="#/venta" data-route="venta" class="nav-link">Nueva Venta</a>
            <a href="#/clientes" data-route="clientes" class="nav-link">Clientes</a>
            <a href="#/historial" data-route="historial" class="nav-link">Historial</a>
            <a href="#/recompensas" data-route="recompensas" class="nav-link">Recompensas</a>
            <a href="#/recibos" data-route="recibos" class="nav-link">Recibos</a>
            <a href="#/contabilidad" data-route="contabilidad" class="nav-link">Contabilidad</a>
          </nav>
          <div class="flex items-center gap-3">
            <span class="hidden sm:block text-xs text-slate-400">${esc(email)}</span>
            <button id="logoutBtn" class="btn-secondary text-sm px-3 py-1.5">Salir</button>
          </div>
        </div>
        <nav class="md:hidden flex items-center gap-1 overflow-x-auto px-3 pb-2">
          <a href="#/dashboard" data-route="dashboard" class="nav-link text-sm">Dashboard</a>
          <a href="#/venta" data-route="venta" class="nav-link text-sm">Venta</a>
          <a href="#/clientes" data-route="clientes" class="nav-link text-sm">Clientes</a>
          <a href="#/historial" data-route="historial" class="nav-link text-sm">Historial</a>
          <a href="#/recompensas" data-route="recompensas" class="nav-link text-sm">Recompensas</a>
          <a href="#/recibos" data-route="recibos" class="nav-link text-sm">Recibos</a>
          <a href="#/contabilidad" data-route="contabilidad" class="nav-link text-sm">Contabilidad</a>
        </nav>
      </header>
      <main class="flex-1 max-w-7xl w-full mx-auto px-4 py-6" id="outlet"></main>
      <footer class="no-print text-center text-xs text-slate-300 py-6">B Fresas Lovers 💗</footer>
    </div>
  `;
  document.getElementById('logoutBtn').onclick = async () => {
    await supabase.auth.signOut();
    location.hash = '';
  };
}

function renderLogin() {
  app.innerHTML = `
    <div class="min-h-screen flex items-center justify-center px-4 bg-gradient-to-br from-blush-50 via-white to-mint-50">
      <div class="card w-full max-w-sm p-8">
        <div class="text-center mb-6">
          <div class="text-4xl mb-2">🍓</div>
          <h1 class="font-heading text-2xl font-bold text-blush-600">B Fresas Lovers</h1>
          <p class="text-xs text-slate-400 mt-1">hecho para los verdaderos lovers.</p>
        </div>
        <form id="loginForm" class="space-y-4">
          <div>
            <label class="label">Correo electrónico</label>
            <input required type="email" name="email" class="input" placeholder="tucorreo@ejemplo.com" />
          </div>
          <div>
            <label class="label">Contraseña</label>
            <input required type="password" name="password" class="input" placeholder="••••••••" />
          </div>
          <p id="loginError" class="text-rose-500 text-sm hidden"></p>
          <button type="submit" class="btn-primary w-full py-3">Iniciar sesión</button>
        </form>
      </div>
    </div>
  `;
  const form = document.getElementById('loginForm');
  form.onsubmit = async (e) => {
    e.preventDefault();
    const fd = new FormData(form);
    const btn = form.querySelector('button');
    btn.disabled = true;
    btn.textContent = 'Entrando…';
    const { error } = await supabase.auth.signInWithPassword({
      email: fd.get('email'),
      password: fd.get('password'),
    });
    if (error) {
      const errEl = document.getElementById('loginError');
      errEl.textContent = 'No se pudo iniciar sesión. Verifica tus datos.';
      errEl.classList.remove('hidden');
      btn.disabled = false;
      btn.textContent = 'Iniciar sesión';
    }
  };
}

// ---------- DASHBOARD ----------
async function pageDashboard(outlet) {
  outlet.innerHTML = `<div class="text-center text-slate-400 py-20">Cargando…</div>`;
  const start = todayStartISO();

  const [ordersRes, customersRes, itemsRes] = await Promise.all([
    supabase.from('orders').select('*').gte('created_at', start).order('created_at', { ascending: false }),
    supabase.from('Customers').select('ID', { count: 'exact', head: true }),
    supabase.from('order_items').select('quantity, created_at').gte('created_at', start),
  ]);

  const orders = ordersRes.data || [];
  const totalHoy = orders.reduce((s, o) => s + Number(o.total || 0), 0);
  const porMetodo = { cash: 0, card: 0, ath_movil: 0, other: 0 };
  const porCanal = { store: 0, doordash: 0, other: 0 };
  orders.forEach((o) => {
    if (o.payment_method && porMetodo[o.payment_method] !== undefined) porMetodo[o.payment_method] += Number(o.total || 0);
    if (o.sales_channel && porCanal[o.sales_channel] !== undefined) porCanal[o.sales_channel] += Number(o.total || 0);
  });
  const productosVendidos = (itemsRes.data || []).reduce((s, i) => s + Number(i.quantity || 0), 0);

  // recent sales (overall, not just today)
  const { data: recent } = await supabase
    .from('orders')
    .select('id, total, payment_method, sales_channel, created_at, customer_id, Customers(Name)')
    .order('created_at', { ascending: false })
    .limit(8);

  outlet.innerHTML = `
    <h1 class="font-heading text-2xl font-bold text-slate-700 mb-5">Dashboard</h1>
    <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
      ${statCard('Ventas de hoy', orders.length, '🧾')}
      ${statCard('Total vendido hoy', fmt(totalHoy), '💰')}
      ${statCard('Clientes registrados', customersRes.count ?? 0, '💗')}
      ${statCard('Productos vendidos hoy', productosVendidos, '🍓')}
    </div>
    <div class="grid md:grid-cols-2 gap-4 mb-6">
      <div class="card p-5">
        <h2 class="font-heading font-bold text-slate-600 mb-3">Ventas por método de pago</h2>
        <div class="space-y-2">
          ${Object.entries(PAYMENT_LABELS).map(([k, label]) => rowStat(label, fmt(porMetodo[k]))).join('')}
        </div>
      </div>
      <div class="card p-5">
        <h2 class="font-heading font-bold text-slate-600 mb-3">Ventas por canal</h2>
        <div class="space-y-2">
          ${Object.entries(CHANNEL_LABELS).map(([k, label]) => rowStat(label, fmt(porCanal[k]))).join('')}
        </div>
      </div>
    </div>
    <div class="card p-5">
      <h2 class="font-heading font-bold text-slate-600 mb-3">Ventas recientes</h2>
      <div class="divide-y divide-blush-50">
        ${(recent || []).map((o) => `
          <a href="#/recibo/${o.id}" class="flex items-center justify-between py-3 hover:bg-blush-50 -mx-2 px-2 rounded-xl">
            <div>
              <div class="font-semibold text-slate-600">Orden #${o.id} · ${esc(o.Customers?.Name || 'Sin cliente')}</div>
              <div class="text-xs text-slate-400">${fmtDateTime(o.created_at)}</div>
            </div>
            <div class="text-right">
              <div class="font-bold text-blush-600">${fmt(o.total)}</div>
              <div class="text-xs text-slate-400">${CHANNEL_LABELS[o.sales_channel] || '—'} · ${PAYMENT_LABELS[o.payment_method] || '—'}</div>
            </div>
          </a>
        `).join('') || '<p class="text-slate-400 text-sm py-4">Aún no hay ventas.</p>'}
      </div>
    </div>
  `;
}

function statCard(label, value, icon) {
  return `
    <div class="card p-4">
      <div class="text-xl mb-1">${icon}</div>
      <div class="text-2xl font-bold text-slate-700">${value}</div>
      <div class="text-xs text-slate-400">${label}</div>
    </div>
  `;
}
function rowStat(label, value) {
  return `<div class="flex items-center justify-between text-sm"><span class="text-slate-500">${label}</span><span class="font-semibold text-slate-700">${value}</span></div>`;
}

// ---------- NUEVA VENTA (POS) ----------
const ventaState = {
  customer: null, // {ID, Name} or null
  cart: [], // {key, item_id, item_name, size_id, size_name, unit_price, extras:[{id,name,price}], quantity, lineUnitTotal, lineTotal}
  categories: [],
  items: [],
  extras: [],
  discount: 0,
  paymentMethod: 'cash',
  salesChannel: 'store',
  notes: '',
};

function resetVenta() {
  ventaState.customer = null;
  ventaState.cart = [];
  ventaState.discount = 0;
  ventaState.paymentMethod = 'cash';
  ventaState.salesChannel = 'store';
  ventaState.notes = '';
}

async function pageVenta(outlet) {
  resetVenta();
  outlet.innerHTML = `<div class="text-center text-slate-400 py-20">Cargando menú…</div>`;

  const [catRes, extrasRes] = await Promise.all([
    supabase.from('menu_categories').select('*').eq('active', true).order('sort_order'),
    supabase.from('menu_extras').select('*').eq('active', true).order('group_name').order('sort_order'),
  ]);
  ventaState.categories = catRes.data || [];
  ventaState.extras = extrasRes.data || [];

  renderVenta(outlet);
}

function renderVenta(outlet) {
  outlet.innerHTML = `
    <h1 class="font-heading text-2xl font-bold text-slate-700 mb-5">Nueva Venta</h1>
    <div class="grid lg:grid-cols-3 gap-5">
      <div class="lg:col-span-2 space-y-5">
        <div class="card p-5">
          <h2 class="font-heading font-bold text-slate-600 mb-3">1. Cliente</h2>
          <div id="customerBox"></div>
        </div>
        <div class="card p-5">
          <h2 class="font-heading font-bold text-slate-600 mb-3">2. Productos</h2>
          <div id="menuBox"></div>
        </div>
      </div>
      <div class="space-y-5">
        <div class="card p-5">
          <h2 class="font-heading font-bold text-slate-600 mb-3">Carrito</h2>
          <div id="cartBox"></div>
        </div>
        <div class="card p-5">
          <h2 class="font-heading font-bold text-slate-600 mb-3">Resumen</h2>
          <div id="summaryBox"></div>
        </div>
      </div>
    </div>
  `;
  renderCustomerBox();
  renderMenuBox();
  renderCart();
  renderSummary();
}

function renderCustomerBox() {
  const box = document.getElementById('customerBox');
  if (ventaState.customer) {
    box.innerHTML = `
      <div class="flex items-center justify-between bg-mint-50 rounded-xl px-4 py-3">
        <div>
          <div class="font-semibold text-slate-700">${esc(ventaState.customer.Name)}</div>
          <div class="text-xs text-slate-400">Cliente seleccionado</div>
        </div>
        <button id="clearCustomer" class="btn-secondary text-sm px-3 py-1.5">Quitar</button>
      </div>
    `;
    document.getElementById('clearCustomer').onclick = () => { ventaState.customer = null; renderCustomerBox(); };
    return;
  }
  box.innerHTML = `
    <div class="flex gap-2 mb-2">
      <input id="custSearch" class="input" placeholder="Buscar cliente por nombre…" />
      <button id="noCustBtn" class="btn-secondary whitespace-nowrap px-4">Sin cliente</button>
      <button id="newCustBtn" class="btn-mint whitespace-nowrap px-4">+ Nuevo</button>
    </div>
    <div id="custResults" class="space-y-1 max-h-40 overflow-y-auto"></div>
  `;
  document.getElementById('noCustBtn').onclick = () => { ventaState.customer = { ID: null, Name: 'Sin cliente' }; ventaState.customer = null; renderCustomerBox(); renderSummary(); };
  document.getElementById('newCustBtn').onclick = () => openNewCustomerModal((c) => { ventaState.customer = c; renderCustomerBox(); renderSummary(); });
  const searchInput = document.getElementById('custSearch');
  let t;
  searchInput.oninput = () => {
    clearTimeout(t);
    t = setTimeout(async () => {
      const q = searchInput.value.trim();
      const results = document.getElementById('custResults');
      if (!q) { results.innerHTML = ''; return; }
      const { data } = await supabase.from('Customers').select('ID, Name, Email, Teléfono').ilike('Name', `%${q}%`).limit(8);
      results.innerHTML = (data || []).map((c) => `
        <button data-id="${c.ID}" class="cust-pick w-full text-left px-3 py-2 rounded-lg hover:bg-blush-50 text-sm">
          <span class="font-semibold">${esc(c.Name)}</span>
          <span class="text-slate-400 ml-2">${esc(c.Teléfono || c.Email || '')}</span>
        </button>
      `).join('') || '<p class="text-xs text-slate-400 px-2">Sin resultados.</p>';
      results.querySelectorAll('.cust-pick').forEach((btn) => {
        btn.onclick = () => {
          const c = data.find((x) => String(x.ID) === btn.dataset.id);
          ventaState.customer = c;
          renderCustomerBox();
          renderSummary();
        };
      });
    }, 250);
  };
}

function openNewCustomerModal(onCreated) {
  const wrap = document.createElement('div');
  wrap.className = 'fixed inset-0 bg-black/30 flex items-center justify-center z-50 px-4';
  wrap.innerHTML = `
    <div class="card p-6 w-full max-w-sm">
      <h3 class="font-heading font-bold text-slate-700 mb-4">Nuevo cliente</h3>
      <form id="newCustForm" class="space-y-3">
        <div><label class="label">Nombre</label><input required name="name" class="input" /></div>
        <div><label class="label">Teléfono</label><input name="phone" class="input" /></div>
        <div><label class="label">Email</label><input name="email" type="email" class="input" /></div>
        <div class="flex gap-2 pt-2">
          <button type="button" id="cancelNewCust" class="btn-secondary flex-1 py-2">Cancelar</button>
          <button type="submit" class="btn-primary flex-1 py-2">Crear</button>
        </div>
      </form>
    </div>
  `;
  document.body.appendChild(wrap);
  wrap.querySelector('#cancelNewCust').onclick = () => wrap.remove();
  wrap.querySelector('#newCustForm').onsubmit = async (e) => {
    e.preventDefault();
    const fd = new FormData(e.target);
    const { data: cust, error } = await supabase.from('Customers').insert({
      Name: fd.get('name'), Teléfono: fd.get('phone') || null, Email: fd.get('email') || null,
    }).select().single();
    if (error) { toast('No se pudo crear el cliente.', 'red'); return; }
    const { error: cardErr } = await supabase.from('Loyalty_ cards').insert({
      Custumer_id: cust.ID, Stamps: 0, Reward_available: false, cycle_number: 1,
    });
    if (cardErr) toast('Cliente creado, pero falló la tarjeta de fidelidad.', 'red');
    wrap.remove();
    toast('Cliente creado 💗', 'mint');
    onCreated(cust);
  };
}

async function renderMenuBox() {
  const box = document.getElementById('menuBox');
  if (!ventaState.categories.length) {
    box.innerHTML = '<p class="text-sm text-slate-400">No hay categorías activas en el menú.</p>';
    return;
  }
  box.innerHTML = `
    <div class="flex gap-2 overflow-x-auto pb-2 mb-3" id="catTabs"></div>
    <div id="itemsGrid" class="grid sm:grid-cols-2 gap-3"></div>
  `;
  const tabs = document.getElementById('catTabs');
  let activeCat = ventaState.categories[0].id;
  tabs.innerHTML = ventaState.categories.map((c) => `
    <button data-id="${c.id}" class="cat-tab nav-link ${c.id === activeCat ? 'active' : ''}">${esc(c.name)}</button>
  `).join('');
  async function loadItems(catId) {
    const grid = document.getElementById('itemsGrid');
    grid.innerHTML = '<p class="text-sm text-slate-400 col-span-2">Cargando…</p>';
    const { data } = await supabase.from('menu_items').select('*').eq('active', true).eq('category_id', catId).order('sort_order');
    ventaState.items = data || [];
    grid.innerHTML = (data || []).map((it) => `
      <button data-id="${it.id}" class="item-btn text-left card p-3 hover:border-blush-300 border-2 border-transparent">
        <div class="font-semibold text-slate-700 text-sm">${esc(it.name)}</div>
        <div class="text-xs text-slate-400 mt-1">${it.has_sizes ? 'Elige tamaño' : fmt(it.base_price)}</div>
      </button>
    `).join('') || '<p class="text-sm text-slate-400 col-span-2">No hay productos en esta categoría.</p>';
    grid.querySelectorAll('.item-btn').forEach((btn) => {
      btn.onclick = () => openItemModal(ventaState.items.find((i) => String(i.id) === btn.dataset.id));
    });
  }
  tabs.querySelectorAll('.cat-tab').forEach((btn) => {
    btn.onclick = () => {
      tabs.querySelectorAll('.cat-tab').forEach((b) => b.classList.remove('active'));
      btn.classList.add('active');
      loadItems(btn.dataset.id);
    };
  });
  loadItems(activeCat);
}

async function openItemModal(item) {
  let sizes = [];
  if (item.has_sizes) {
    const { data } = await supabase.from('menu_item_sizes').select('*').eq('item_id', item.id).eq('active', true).order('sort_order');
    sizes = data || [];
  }
  const extrasByGroup = {};
  ventaState.extras.forEach((ex) => {
    const g = ex.group_name || 'Extras';
    (extrasByGroup[g] ||= []).push(ex);
  });

  const wrap = document.createElement('div');
  wrap.className = 'fixed inset-0 bg-black/30 flex items-center justify-center z-50 px-4';
  wrap.innerHTML = `
    <div class="card p-6 w-full max-w-md max-h-[85vh] overflow-y-auto">
      <h3 class="font-heading font-bold text-slate-700 mb-1">${esc(item.name)}</h3>
      ${item.description ? `<p class="text-xs text-slate-400 mb-3">${esc(item.description)}</p>` : ''}
      ${sizes.length ? `
        <div class="mb-4">
          <label class="label">Tamaño</label>
          <div class="grid grid-cols-2 gap-2" id="sizeOpts">
            ${sizes.map((s, idx) => `
              <label class="flex items-center justify-between border-2 rounded-xl px-3 py-2 cursor-pointer text-sm ${idx === 0 ? 'border-blush-400 bg-blush-50' : 'border-blush-100'}">
                <input type="radio" name="size" value="${s.id}" data-price="${s.price}" class="hidden" ${idx === 0 ? 'checked' : ''} />
                <span>${esc(s.size_name || s.size_oz + ' oz')}</span><span class="font-semibold">${fmt(s.price)}</span>
              </label>
            `).join('')}
          </div>
        </div>
      ` : ''}
      ${Object.keys(extrasByGroup).length ? `
        <div class="mb-4 space-y-3">
          ${Object.entries(extrasByGroup).map(([group, list]) => `
            <div>
              <label class="label">${esc(group)}</label>
              <div class="space-y-1">
                ${list.map((ex) => `
                  <label class="flex items-center justify-between text-sm px-3 py-1.5 rounded-lg hover:bg-blush-50 cursor-pointer">
                    <span class="flex items-center gap-2"><input type="checkbox" class="extra-chk" value="${ex.id}" data-name="${esc(ex.name)}" data-price="${ex.price}" /> ${esc(ex.name)}</span>
                    <span class="text-slate-400">${ex.price > 0 ? '+' + fmt(ex.price) : 'gratis'}</span>
                  </label>
                `).join('')}
              </div>
            </div>
          `).join('')}
        </div>
      ` : ''}
      <div class="flex items-center gap-3 mb-4">
        <label class="label mb-0">Cantidad</label>
        <div class="flex items-center gap-2">
          <button type="button" id="qtyMinus" class="btn-secondary w-8 h-8 flex items-center justify-center">-</button>
          <span id="qtyVal" class="font-bold w-6 text-center">1</span>
          <button type="button" id="qtyPlus" class="btn-secondary w-8 h-8 flex items-center justify-center">+</button>
        </div>
      </div>
      <div class="flex gap-2">
        <button type="button" id="cancelItem" class="btn-secondary flex-1 py-2">Cancelar</button>
        <button type="button" id="addItem" class="btn-primary flex-1 py-2">Agregar</button>
      </div>
    </div>
  `;
  document.body.appendChild(wrap);

  wrap.querySelectorAll('input[name=size]').forEach((r) => {
    r.addEventListener('change', () => {
      wrap.querySelectorAll('#sizeOpts label').forEach((l) => l.classList.remove('border-blush-400', 'bg-blush-50'));
      r.closest('label').classList.add('border-blush-400', 'bg-blush-50');
    });
  });

  let qty = 1;
  const qtyVal = wrap.querySelector('#qtyVal');
  wrap.querySelector('#qtyMinus').onclick = () => { qty = Math.max(1, qty - 1); qtyVal.textContent = qty; };
  wrap.querySelector('#qtyPlus').onclick = () => { qty += 1; qtyVal.textContent = qty; };
  wrap.querySelector('#cancelItem').onclick = () => wrap.remove();

  wrap.querySelector('#addItem').onclick = () => {
    let sizeId = null, sizeName = null, unitPrice = Number(item.base_price || 0);
    if (sizes.length) {
      const checked = wrap.querySelector('input[name=size]:checked');
      const s = sizes.find((x) => String(x.id) === checked.value);
      sizeId = s.id; sizeName = s.size_name || `${s.size_oz} oz`; unitPrice = Number(s.price);
    }
    const extras = Array.from(wrap.querySelectorAll('.extra-chk:checked')).map((c) => ({
      id: c.value, name: c.dataset.name, price: Number(c.dataset.price),
    }));
    const extrasTotal = extras.reduce((s, e) => s + e.price, 0);
    const lineUnitTotal = unitPrice + extrasTotal;
    ventaState.cart.push({
      key: uid(), item_id: item.id, item_name: item.name, size_id: sizeId, size_name: sizeName,
      unit_price: lineUnitTotal, quantity: qty, extras, lineTotal: lineUnitTotal * qty,
    });
    wrap.remove();
    renderCart();
    renderSummary();
    toast('Agregado al carrito 🍓', 'mint');
  };
}

function renderCart() {
  const box = document.getElementById('cartBox');
  if (!ventaState.cart.length) {
    box.innerHTML = '<p class="text-sm text-slate-400">El carrito está vacío.</p>';
    return;
  }
  box.innerHTML = `
    <div class="space-y-3">
      ${ventaState.cart.map((line) => `
        <div class="border-b border-blush-50 pb-3">
          <div class="flex justify-between items-start">
            <div>
              <div class="font-semibold text-sm text-slate-700">${esc(line.item_name)}${line.size_name ? ' · ' + esc(line.size_name) : ''}</div>
              ${line.extras.length ? `<div class="text-xs text-slate-400">Extras: ${line.extras.map((e) => esc(e.name)).join(', ')}</div>` : ''}
            </div>
            <button data-key="${line.key}" class="rm-line text-rose-400 text-xs font-semibold">Quitar</button>
          </div>
          <div class="flex items-center justify-between mt-1">
            <div class="flex items-center gap-2">
              <button data-key="${line.key}" class="qty-minus btn-secondary w-6 h-6 flex items-center justify-center text-xs">-</button>
              <span class="text-sm font-semibold w-5 text-center">${line.quantity}</span>
              <button data-key="${line.key}" class="qty-plus btn-secondary w-6 h-6 flex items-center justify-center text-xs">+</button>
            </div>
            <div class="font-bold text-blush-600 text-sm">${fmt(line.lineTotal)}</div>
          </div>
        </div>
      `).join('')}
    </div>
  `;
  box.querySelectorAll('.rm-line').forEach((b) => b.onclick = () => {
    ventaState.cart = ventaState.cart.filter((l) => l.key !== b.dataset.key);
    renderCart(); renderSummary();
  });
  box.querySelectorAll('.qty-minus').forEach((b) => b.onclick = () => {
    const line = ventaState.cart.find((l) => l.key === b.dataset.key);
    line.quantity = Math.max(1, line.quantity - 1);
    line.lineTotal = line.unit_price * line.quantity;
    renderCart(); renderSummary();
  });
  box.querySelectorAll('.qty-plus').forEach((b) => b.onclick = () => {
    const line = ventaState.cart.find((l) => l.key === b.dataset.key);
    line.quantity += 1;
    line.lineTotal = line.unit_price * line.quantity;
    renderCart(); renderSummary();
  });
}

function computeTotals() {
  const subtotal = ventaState.cart.reduce((s, l) => s + l.lineTotal, 0);
  const discount = Number(ventaState.discount) || 0;
  const taxable = Math.max(0, subtotal - discount);
  const tax = taxable * 0.115;
  const total = taxable + tax;
  return { subtotal, discount, tax, total };
}

function renderSummary() {
  const box = document.getElementById('summaryBox');
  const { subtotal, discount, tax, total } = computeTotals();
  box.innerHTML = `
    <div class="space-y-2 text-sm mb-4">
      <div class="flex justify-between"><span class="text-slate-500">Subtotal</span><span class="font-semibold">${fmt(subtotal)}</span></div>
      <div class="flex justify-between items-center"><span class="text-slate-500">Descuento</span>
        <input id="discountInput" type="number" min="0" step="0.01" value="${ventaState.discount || 0}" class="input w-24 text-right py-1" />
      </div>
      <div class="flex justify-between"><span class="text-slate-500">IVU (11.5%)</span><span class="font-semibold">${fmt(tax)}</span></div>
      <div class="flex justify-between text-base pt-2 border-t border-blush-100"><span class="font-bold">Total</span><span class="font-bold text-blush-600">${fmt(total)}</span></div>
    </div>
    <div class="mb-3">
      <label class="label">Método de pago</label>
      <select id="paymentSelect" class="input">
        ${Object.entries(PAYMENT_LABELS).map(([k, l]) => `<option value="${k}" ${ventaState.paymentMethod === k ? 'selected' : ''}>${l}</option>`).join('')}
      </select>
    </div>
    <div class="mb-3">
      <label class="label">Canal de venta</label>
      <select id="channelSelect" class="input">
        ${Object.entries(CHANNEL_LABELS).map(([k, l]) => `<option value="${k}" ${ventaState.salesChannel === k ? 'selected' : ''}>${l}</option>`).join('')}
      </select>
    </div>
    <div class="mb-4">
      <label class="label">Notas de la venta</label>
      <textarea id="notesInput" class="input" rows="2" placeholder="Notas (opcional)">${esc(ventaState.notes)}</textarea>
    </div>
    <button id="confirmVenta" class="btn-primary w-full py-3" ${ventaState.cart.length ? '' : 'disabled'}>Confirmar venta</button>
  `;
  document.getElementById('discountInput').oninput = (e) => { ventaState.discount = Number(e.target.value) || 0; renderSummary(); };
  document.getElementById('paymentSelect').onchange = (e) => { ventaState.paymentMethod = e.target.value; };
  document.getElementById('channelSelect').onchange = (e) => { ventaState.salesChannel = e.target.value; };
  document.getElementById('notesInput').oninput = (e) => { ventaState.notes = e.target.value; };
  const confirmBtn = document.getElementById('confirmVenta');
  if (confirmBtn) confirmBtn.onclick = confirmVenta;
}

async function confirmVenta() {
  const btn = document.getElementById('confirmVenta');
  btn.disabled = true;
  btn.textContent = 'Guardando…';
  const { subtotal, discount, tax, total } = computeTotals();

  try {
    const { data: order, error: orderErr } = await supabase.from('orders').insert({
      customer_id: ventaState.customer?.ID || null,
      status: 'completed',
      payment_method: ventaState.paymentMethod,
      subtotal, discount, tax, total,
      notes: ventaState.notes || null,
      sales_channel: ventaState.salesChannel,
    }).select().single();
    if (orderErr) throw orderErr;

    const itemsPayload = ventaState.cart.map((l) => ({
      order_id: order.id,
      item_id: l.item_id,
      size_id: l.size_id,
      item_name: l.item_name,
      size_name: l.size_name,
      unit_price: l.unit_price,
      quantity: l.quantity,
      line_total: l.lineTotal,
      notes: l.extras.length ? `Extras: ${l.extras.map((e) => e.name).join(', ')}` : null,
    }));
    const { error: itemsErr } = await supabase.from('order_items').insert(itemsPayload);
    if (itemsErr) throw itemsErr;

    let loyaltyMsg = 'Venta sin cliente asociado — no aplica fidelidad.';
    let loyaltyResult = null;
    if (ventaState.customer?.ID) {
      const { data: rpcData, error: rpcErr } = await supabase.rpc('register_purchase', {
        p_customer_id: ventaState.customer.ID, p_amount: total,
      });
      if (rpcErr) {
        loyaltyMsg = 'La venta se guardó, pero no se pudo actualizar la fidelidad: ' + rpcErr.message;
      } else {
        loyaltyResult = rpcData;
        const earned = rpcData.stamp_earned === 1;
        loyaltyMsg = earned
          ? `¡Sello ganado! Sellos actuales: ${rpcData.stamps}/10.`
          : `No se ganó sello esta vez (compra menor a $8). Sellos actuales: ${rpcData.stamps}/10.`;
        if (rpcData.reward_created) loyaltyMsg += ` 🎉 ¡Recompensa desbloqueada: ${rpcData.reward_created}!`;
      }
    }

    const receiptNotes = ventaState.customer?.ID
      ? `Fidelidad — ${loyaltyMsg}`
      : 'Venta sin cliente asociado.';

    await supabase.from('receipts').insert({
      receipt_type: 'sale',
      receipt_date: todayDateStr(),
      vendor: null,
      amount: total,
      order_id: order.id,
      notes: receiptNotes,
    });

    toast('Venta registrada 💗', 'mint');
    showVentaResult(order.id, loyaltyMsg, loyaltyResult);
  } catch (err) {
    console.error(err);
    toast('Ocurrió un error al guardar la venta.', 'red');
    btn.disabled = false;
    btn.textContent = 'Confirmar venta';
  }
}

function showVentaResult(orderId, loyaltyMsg, loyaltyResult) {
  const outlet = document.getElementById('outlet');
  outlet.innerHTML = `
    <div class="max-w-md mx-auto card p-8 text-center">
      <div class="text-5xl mb-3">💗</div>
      <h2 class="font-heading text-xl font-bold text-slate-700 mb-2">¡Venta #${orderId} completada!</h2>
      <p class="text-sm text-slate-500 mb-4">${esc(loyaltyMsg)}</p>
      ${loyaltyResult?.reward_created ? `<div class="chip chip-lilac mb-4">🎁 ${esc(loyaltyResult.reward_created)}</div>` : ''}
      <div class="flex gap-2 justify-center">
        <a href="#/recibo/${orderId}" class="btn-primary px-5 py-2.5">Ver recibo</a>
        <a href="#/venta" class="btn-secondary px-5 py-2.5">Nueva venta</a>
      </div>
    </div>
  `;
}

// ---------- CLIENTES ----------
async function pageClientes(outlet) {
  outlet.innerHTML = `
    <div class="flex items-center justify-between mb-5">
      <h1 class="font-heading text-2xl font-bold text-slate-700">Clientes</h1>
      <button id="addCustBtn" class="btn-primary px-4 py-2">+ Nuevo cliente</button>
    </div>
    <input id="custSearchMain" class="input mb-4 max-w-sm" placeholder="Buscar por nombre…" />
    <div id="custList" class="grid md:grid-cols-2 gap-3"></div>
  `;
  document.getElementById('addCustBtn').onclick = () => openNewCustomerModal(() => loadCustomers());
  let t;
  document.getElementById('custSearchMain').oninput = (e) => {
    clearTimeout(t);
    t = setTimeout(() => loadCustomers(e.target.value), 250);
  };
  async function loadCustomers(q = '') {
    const list = document.getElementById('custList');
    list.innerHTML = '<p class="text-slate-400 text-sm">Cargando…</p>';
    let query = supabase.from('Customers').select('ID, Name, Email, Teléfono, created_at, "Loyalty_ cards"(Stamps, Reward_available, cycle_number)').order('created_at', { ascending: false });
    if (q) query = query.ilike('Name', `%${q}%`);
    const { data, error } = await query;
    if (error) { list.innerHTML = `<p class="text-rose-500 text-sm">${esc(error.message)}</p>`; return; }
    list.innerHTML = (data || []).map((c) => {
      const card = Array.isArray(c['Loyalty_ cards']) ? c['Loyalty_ cards'][0] : c['Loyalty_ cards'];
      return `
      <div class="card p-4">
        <div class="flex justify-between items-start">
          <div>
            <div class="font-semibold text-slate-700">${esc(c.Name)}</div>
            <div class="text-xs text-slate-400">${esc(c.Teléfono || '')} ${c.Email ? '· ' + esc(c.Email) : ''}</div>
            <div class="text-xs text-slate-300 mt-1">Cliente desde ${fmtDate(c.created_at)}</div>
          </div>
          <div class="text-right">
            <div class="chip chip-pink">${card?.Stamps ?? 0}/10 sellos</div>
            ${card?.Reward_available ? '<div class="chip chip-lilac mt-1">Recompensa disponible</div>' : ''}
          </div>
        </div>
      </div>
    `;
    }).join('') || '<p class="text-slate-400 text-sm">No se encontraron clientes.</p>';
  }
  loadCustomers();
}

// ---------- HISTORIAL DE VENTAS ----------
async function pageHistorial(outlet) {
  outlet.innerHTML = `
    <h1 class="font-heading text-2xl font-bold text-slate-700 mb-5">Historial de ventas</h1>
    <div class="card p-4 mb-5 grid sm:grid-cols-2 lg:grid-cols-5 gap-3">
      <input id="fOrder" class="input" placeholder="# de orden" />
      <input id="fCustomer" class="input" placeholder="Cliente" />
      <input id="fDate" type="date" class="input" />
      <select id="fPayment" class="input">
        <option value="">Método de pago</option>
        ${Object.entries(PAYMENT_LABELS).map(([k, l]) => `<option value="${k}">${l}</option>`).join('')}
      </select>
      <select id="fChannel" class="input">
        <option value="">Canal</option>
        ${Object.entries(CHANNEL_LABELS).map(([k, l]) => `<option value="${k}">${l}</option>`).join('')}
      </select>
    </div>
    <div class="card overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-slate-400 border-b border-blush-50">
            <th class="p-3">Orden</th><th class="p-3">Fecha</th><th class="p-3">Cliente</th>
            <th class="p-3">Subtotal</th><th class="p-3">IVU</th><th class="p-3">Total</th>
            <th class="p-3">Pago</th><th class="p-3">Canal</th>
          </tr>
        </thead>
        <tbody id="histBody"></tbody>
      </table>
    </div>
  `;
  let allOrders = [];
  async function load() {
    const { data } = await supabase.from('orders').select('*, Customers(Name)').order('created_at', { ascending: false }).limit(300);
    allOrders = data || [];
    applyFilters();
  }
  function applyFilters() {
    const orderQ = document.getElementById('fOrder').value.trim();
    const custQ = document.getElementById('fCustomer').value.trim().toLowerCase();
    const dateQ = document.getElementById('fDate').value;
    const payQ = document.getElementById('fPayment').value;
    const chanQ = document.getElementById('fChannel').value;
    const rows = allOrders.filter((o) => {
      if (orderQ && String(o.id) !== orderQ) return false;
      if (custQ && !(o.Customers?.Name || '').toLowerCase().includes(custQ)) return false;
      if (dateQ && !o.created_at.startsWith(dateQ)) return false;
      if (payQ && o.payment_method !== payQ) return false;
      if (chanQ && o.sales_channel !== chanQ) return false;
      return true;
    });
    const body = document.getElementById('histBody');
    body.innerHTML = rows.map((o) => `
      <tr class="border-b border-blush-50 hover:bg-blush-50 cursor-pointer" onclick="location.hash='#/recibo/${o.id}'">
        <td class="p-3 font-semibold">#${o.id}</td>
        <td class="p-3">${fmtDateTime(o.created_at)}</td>
        <td class="p-3">${esc(o.Customers?.Name || 'Sin cliente')}</td>
        <td class="p-3">${fmt(o.subtotal)}</td>
        <td class="p-3">${fmt(o.tax)}</td>
        <td class="p-3 font-bold text-blush-600">${fmt(o.total)}</td>
        <td class="p-3"><span class="chip chip-gray">${PAYMENT_LABELS[o.payment_method] || '—'}</span></td>
        <td class="p-3"><span class="chip chip-mint">${CHANNEL_LABELS[o.sales_channel] || '—'}</span></td>
      </tr>
    `).join('') || `<tr><td colspan="8" class="p-6 text-center text-slate-400">Sin resultados.</td></tr>`;
  }
  ['fOrder', 'fCustomer', 'fDate', 'fPayment', 'fChannel'].forEach((id) => {
    document.getElementById(id).addEventListener('input', applyFilters);
    document.getElementById(id).addEventListener('change', applyFilters);
  });
  load();
}

// ---------- RECOMPENSAS ----------
async function pageRecompensas(outlet) {
  outlet.innerHTML = `
    <h1 class="font-heading text-2xl font-bold text-slate-700 mb-5">Recompensas</h1>
    <div class="card overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="text-left text-slate-400 border-b border-blush-50">
            <th class="p-3">Cliente</th><th class="p-3">Recompensa</th><th class="p-3">Ciclo</th>
            <th class="p-3">Estado</th><th class="p-3">Fecha</th><th class="p-3"></th>
          </tr>
        </thead>
        <tbody id="rewBody"></tbody>
      </table>
    </div>
  `;
  async function load() {
    const { data, error } = await supabase.from('loyalty_rewards').select('*, Customers(Name)').order('created_at', { ascending: false });
    const body = document.getElementById('rewBody');
    if (error) { body.innerHTML = `<tr><td colspan="6" class="p-4 text-rose-500">${esc(error.message)}</td></tr>`; return; }
    const statusChip = { available: 'chip-mint', redeemed: 'chip-gray', expired: 'chip-pink' };
    const statusLabel = { available: 'Disponible', redeemed: 'Redimida', expired: 'Expirada' };
    body.innerHTML = (data || []).map((r) => `
      <tr class="border-b border-blush-50">
        <td class="p-3">${esc(r.Customers?.Name || '—')}</td>
        <td class="p-3">${esc(r.description || r.reward_type)}</td>
        <td class="p-3">${r.cycle_number}</td>
        <td class="p-3"><span class="chip ${statusChip[r.status] || 'chip-gray'}">${statusLabel[r.status] || r.status}</span></td>
        <td class="p-3 text-xs text-slate-400">${fmtDate(r.created_at)}${r.redeemed_at ? ' · redimida ' + fmtDate(r.redeemed_at) : ''}</td>
        <td class="p-3">${r.status === 'available' ? `<button data-id="${r.id}" class="redeemBtn btn-mint text-xs px-3 py-1.5">Redimir</button>` : ''}</td>
      </tr>
    `).join('') || `<tr><td colspan="6" class="p-6 text-center text-slate-400">Sin recompensas todavía.</td></tr>`;
    body.querySelectorAll('.redeemBtn').forEach((btn) => {
      btn.onclick = async () => {
        btn.disabled = true; btn.textContent = '…';
        const { data: res, error: rErr } = await supabase.rpc('redeem_reward', { p_reward_id: btn.dataset.id });
        if (rErr) { toast('No se pudo redimir: ' + rErr.message, 'red'); }
        else { toast(res.message || 'Recompensa redimida 🎉', 'mint'); }
        load();
      };
    });
  }
  load();
}

async function pageContabilidad(outlet) {
  const now = new Date();
  const defaultMonth = now.toISOString().slice(0, 7);
  outlet.innerHTML = '<div class="flex items-center justify-between gap-3 mb-5 flex-wrap"><div><h1 class="font-heading text-2xl font-bold text-slate-700">Contabilidad</h1><p class="text-sm text-slate-400 mt-1">Ventas, gastos y neto mensual desde Supabase.</p></div><div class="flex items-center gap-2"><label class="text-sm font-semibold text-slate-500">Mes</label><input id="acctMonth" type="month" class="input w-auto" value="' + defaultMonth + '" /></div></div><div id="acctContent"><div class="text-center text-slate-400 py-20">Cargando contabilidad…</div></div>';
  const monthInput = document.getElementById('acctMonth');
  monthInput.onchange = () => loadAccounting(monthInput.value);
  await loadAccounting(defaultMonth);
  async function loadAccounting(month) {
    const content = document.getElementById('acctContent'); content.innerHTML = '<div class="text-center text-slate-400 py-20">Cargando…</div>';
    const monthStart = month + '-01'; const next = new Date(monthStart + 'T00:00:00'); next.setMonth(next.getMonth() + 1); const nextMonth = next.toISOString().slice(0,10);
    const [summaryRes, receiptsRes, expensesRes] = await Promise.all([supabase.from('accounting_monthly_summary').select('*').eq('month',monthStart).maybeSingle(),supabase.from('receipts').select('*').gte('receipt_date',monthStart).lt('receipt_date',nextMonth).order('receipt_date',{ascending:false}).order('id',{ascending:false}).limit(100),supabase.from('business_expenses').select('*').gte('expense_date',monthStart).lt('expense_date',nextMonth).order('expense_date',{ascending:false}).order('id',{ascending:false}).limit(100)]);
    if(summaryRes.error){content.innerHTML='<div class="card p-5 text-rose-500 text-sm">No se pudo cargar el resumen: '+esc(summaryRes.error.message)+'</div>';return;}
    const s=summaryRes.data||{sales_cash:0,sales_card:0,sales_ath_movil:0,sales_other:0,sales_doordash:0,sales_total:0,expenses_cash:0,expenses_card:0,expenses_ath_movil:0,expenses_other:0,expenses_total:0,net:0}; const receipts=receiptsRes.data||[]; const expenses=expensesRes.data||[];
    const salesRows=rowStat('💵 Efectivo',fmt(s.sales_cash))+rowStat('💳 Tarjeta',fmt(s.sales_card))+rowStat('📱 ATH Móvil',fmt(s.sales_ath_movil))+rowStat('Otro',fmt(s.sales_other));
    const expenseRows=rowStat('💵 Efectivo',fmt(s.expenses_cash))+rowStat('💳 Tarjeta',fmt(s.expenses_card))+rowStat('📱 ATH Móvil',fmt(s.expenses_ath_movil))+rowStat('Otro',fmt(s.expenses_other));
    const receiptRows=receipts.map(r=>{const label=({sale:'Venta',expense:'Gasto',payment_proof:'Evidencia de pago',platform_report:'Reporte de plataforma'})[r.receipt_type]||r.receipt_type;const isExp=r.receipt_type==='expense';return '<div class="flex items-center justify-between gap-3 border-b border-blush-50 py-2.5"><div class="min-w-0"><div class="font-semibold text-sm text-slate-600 truncate">'+esc(r.vendor||label)+'</div><div class="text-xs text-slate-400">'+label+' · '+fmtDate(r.receipt_date)+(r.payment_method?' · '+(PAYMENT_LABELS[r.payment_method]||r.payment_method):'')+'</div></div><div class="font-bold '+(isExp?'text-slate-600':'text-blush-600')+'">'+(isExp?'-':'')+fmt(r.amount)+'</div></div>';}).join('')||'<p class="text-sm text-slate-400">No hay recibos en este mes.</p>';
    const expenseTable=expenses.map(e=>{const r=receipts.find(x=>x.expense_id===e.id);return '<tr class="border-b border-blush-50"><td class="p-2">'+fmtDate(e.expense_date)+'</td><td class="p-2">'+esc(e.name)+'</td><td class="p-2">'+esc(e.category)+'</td><td class="p-2">'+esc(r?.payment_method?(PAYMENT_LABELS[r.payment_method]||r.payment_method):'—')+'</td><td class="p-2 text-right font-semibold">'+fmt(e.amount)+'</td></tr>';}).join('')||'<tr><td colspan="5" class="p-5 text-center text-slate-400">No hay gastos registrados.</td></tr>';
    content.innerHTML='<div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-5">'+statCard('Ventas',fmt(s.sales_total),'💰')+statCard('Gastos',fmt(s.expenses_total),'🧾')+statCard('Neto',fmt(s.net),'💗')+statCard('DoorDash',fmt(s.sales_doordash),'🛵')+'</div><div class="grid lg:grid-cols-2 gap-5 mb-5"><div class="card p-5"><h2 class="font-heading font-bold text-slate-600 mb-4">Ventas por método</h2><div class="space-y-3">'+salesRows+'<div class="border-t border-blush-100 pt-3">'+rowStat('Total ventas',fmt(s.sales_total))+'</div></div></div><div class="card p-5"><h2 class="font-heading font-bold text-slate-600 mb-4">Gastos por método</h2><div class="space-y-3">'+expenseRows+'<div class="border-t border-blush-100 pt-3">'+rowStat('Total gastos',fmt(s.expenses_total))+'</div></div></div></div><div class="grid lg:grid-cols-2 gap-5"><div class="card p-5"><div class="flex items-center justify-between mb-4"><h2 class="font-heading font-bold text-slate-600">Registrar gasto</h2><span class="chip chip-pink">Contabilidad</span></div><form id="expenseForm" class="space-y-3"><div class="grid sm:grid-cols-2 gap-3"><div><label class="label">Fecha</label><input required id="expenseDate" type="date" class="input" value="'+monthStart+'" /></div><div><label class="label">Monto</label><input required id="expenseAmount" type="number" min="0" step="0.01" class="input" placeholder="0.00" /></div></div><div><label class="label">Descripción</label><input required id="expenseName" class="input" placeholder="Ej. Compra de fresas" /></div><div class="grid sm:grid-cols-2 gap-3"><div><label class="label">Categoría</label><select id="expenseCategory" class="input"><option value="fixed">Fijo</option><option value="variable" selected>Variable</option><option value="payroll">Nómina</option><option value="other">Otro</option></select></div><div><label class="label">Método de pago</label><select id="expensePayment" class="input">'+Object.entries(PAYMENT_LABELS).map(([k,l])=>'<option value="'+k+'">'+l+'</option>').join('')+'</select></div></div><div><label class="label">Notas</label><textarea id="expenseNotes" class="input" rows="2" placeholder="Opcional"></textarea></div><button class="btn-primary w-full py-2.5" type="submit">Guardar gasto</button></form></div><div class="card p-5"><div class="flex items-center justify-between mb-4"><h2 class="font-heading font-bold text-slate-600">Movimientos del mes</h2><span class="text-xs text-slate-400">'+receipts.length+' recibos</span></div><div class="space-y-2 max-h-[420px] overflow-y-auto">'+receiptRows+'</div></div></div><div class="card p-5 mt-5"><h2 class="font-heading font-bold text-slate-600 mb-3">Gastos registrados</h2><div class="overflow-x-auto"><table class="w-full text-sm"><thead><tr class="text-left text-slate-400 border-b border-blush-50"><th class="p-2">Fecha</th><th class="p-2">Descripción</th><th class="p-2">Categoría</th><th class="p-2">Pago</th><th class="p-2 text-right">Monto</th></tr></thead><tbody>'+expenseTable+'</tbody></table></div></div>';
    document.getElementById('expenseForm').onsubmit=async e=>{e.preventDefault();const btn=e.target.querySelector('button[type="submit"]');btn.disabled=true;btn.textContent='Guardando…';const expenseDate=document.getElementById('expenseDate').value,amount=Number(document.getElementById('expenseAmount').value||0),name=document.getElementById('expenseName').value.trim(),category=document.getElementById('expenseCategory').value,paymentMethod=document.getElementById('expensePayment').value,notes=document.getElementById('expenseNotes').value.trim();const {data:expense,error:expenseErr}=await supabase.from('business_expenses').insert({expense_date:expenseDate,category,name,amount,notes:notes||null}).select().single();if(expenseErr){toast('No se pudo guardar el gasto: '+expenseErr.message,'red');btn.disabled=false;btn.textContent='Guardar gasto';return;}const {error:receiptErr}=await supabase.from('receipts').insert({receipt_type:'expense',receipt_date:expenseDate,vendor:name,amount,expense_id:expense.id,payment_method:paymentMethod,notes:notes||null});if(receiptErr){toast('El gasto se guardó, pero no se pudo crear su recibo: '+receiptErr.message,'red');}else{toast('Gasto guardado 💗','mint');}await loadAccounting(month);};
  }
}
// ---------- RECIBOS (lista) ----------
async function pageRecibos(outlet) {
  outlet.innerHTML = `
    <h1 class="font-heading text-2xl font-bold text-slate-700 mb-5">Recibos</h1>
    <div id="recList" class="grid md:grid-cols-2 gap-3"></div>
  `;
  const { data, error } = await supabase
    .from('receipts')
    .select('*, orders(id, total, created_at, Customers(Name))')
    .eq('receipt_type', 'sale')
    .order('created_at', { ascending: false })
    .limit(200);
  const list = document.getElementById('recList');
  if (error) { list.innerHTML = `<p class="text-rose-500 text-sm">${esc(error.message)}</p>`; return; }
  list.innerHTML = (data || []).map((r) => `
    <a href="#/recibo/${r.order_id}" class="card p-4 flex items-center justify-between hover:bg-blush-50">
      <div>
        <div class="font-semibold text-slate-700">Orden #${r.order_id} · ${esc(r.orders?.Customers?.Name || 'Sin cliente')}</div>
        <div class="text-xs text-slate-400">${fmtDate(r.receipt_date)}</div>
      </div>
      <div class="font-bold text-blush-600">${fmt(r.amount)}</div>
    </a>
  `).join('') || '<p class="text-slate-400 text-sm">Aún no hay recibos.</p>';
}

// ---------- RECIBO (detalle imprimible) ----------
async function pageReciboDetalle(outlet, orderId) {
  outlet.innerHTML = `<div class="text-center text-slate-400 py-20">Cargando recibo…</div>`;
  const [{ data: order, error: oErr }, { data: items }, { data: receipt }] = await Promise.all([
    supabase.from('orders').select('*, Customers(Name, Email, Teléfono)').eq('id', orderId).single(),
    supabase.from('order_items').select('*').eq('order_id', orderId).order('id'),
    supabase.from('receipts').select('*').eq('order_id', orderId).eq('receipt_type', 'sale').maybeSingle(),
  ]);
  if (oErr || !order) {
    outlet.innerHTML = `<p class="text-rose-500">No se encontró la orden.</p>`;
    return;
  }
  const loyaltyLine = receipt?.notes?.startsWith('Fidelidad') ? receipt.notes.replace(/^Fidelidad\s*—\s*/, '') : null;

  outlet.innerHTML = `
    <div class="max-w-lg mx-auto">
      <div class="flex justify-end gap-2 mb-3 no-print">
        <button id="printBtn" class="btn-secondary px-4 py-2">Imprimir</button>
        <button id="shareBtn" class="btn-primary px-4 py-2">Compartir</button>
      </div>
      <div class="card print-area p-8">
        <div class="text-center mb-5">
          <div class="text-3xl">🍓</div>
          <div class="font-heading font-bold text-lg text-blush-600">B Fresas Lovers</div>
          <div class="text-xs text-slate-400">hecho para los verdaderos lovers.</div>
        </div>
        <div class="text-sm text-slate-500 mb-4 space-y-0.5">
          <div>Orden #${order.id}</div>
          <div>${fmtDateTime(order.created_at)}</div>
          <div>Cliente: ${esc(order.Customers?.Name || 'Sin cliente')}</div>
        </div>
        <table class="w-full text-sm mb-4">
          <thead><tr class="text-left text-slate-400 border-b border-blush-100"><th class="py-1">Producto</th><th class="py-1 text-center">Cant.</th><th class="py-1 text-right">Precio</th></tr></thead>
          <tbody>
            ${(items || []).map((it) => `
              <tr class="border-b border-blush-50">
                <td class="py-1.5">
                  <div>${esc(it.item_name)}${it.size_name ? ' · ' + esc(it.size_name) : ''}</div>
                  ${it.notes ? `<div class="text-xs text-slate-400">${esc(it.notes)}</div>` : ''}
                </td>
                <td class="py-1.5 text-center">${it.quantity}</td>
                <td class="py-1.5 text-right">${fmt(it.line_total)}</td>
              </tr>
            `).join('')}
          </tbody>
        </table>
        <div class="space-y-1 text-sm mb-4">
          <div class="flex justify-between"><span class="text-slate-500">Subtotal</span><span>${fmt(order.subtotal)}</span></div>
          <div class="flex justify-between"><span class="text-slate-500">Descuento</span><span>${fmt(order.discount)}</span></div>
          <div class="flex justify-between"><span class="text-slate-500">IVU (11.5%)</span><span>${fmt(order.tax)}</span></div>
          <div class="flex justify-between text-base font-bold pt-1 border-t border-blush-100"><span>Total</span><span class="text-blush-600">${fmt(order.total)}</span></div>
        </div>
        <div class="text-xs text-slate-500 mb-4">
          <div>Método de pago: ${PAYMENT_LABELS[order.payment_method] || '—'}</div>
          <div>Canal de venta: ${CHANNEL_LABELS[order.sales_channel] || '—'}</div>
          ${order.notes ? `<div>Notas: ${esc(order.notes)}</div>` : ''}
        </div>
        ${loyaltyLine ? `<div class="bg-mint-50 text-mint-600 text-xs rounded-xl px-3 py-2 mb-4">💗 ${esc(loyaltyLine)}</div>` : ''}
        <p class="text-center text-sm text-blush-500 font-semibold">Gracias por apoyar a B Fresas Lovers 💗</p>
      </div>
    </div>
  `;
  document.getElementById('printBtn').onclick = () => window.print();
  document.getElementById('shareBtn').onclick = async () => {
    if (navigator.share) {
      try { await navigator.share({ title: `Recibo #${order.id} — B Fresas Lovers`, text: `Total: ${fmt(order.total)}`, url: location.href }); }
      catch (_) {}
    } else {
      await navigator.clipboard.writeText(location.href);
      toast('Enlace copiado 💗', 'mint');
    }
  };
}

// ---------- init ----------
(async function start() {
  await initAuth();
  render();
})();
