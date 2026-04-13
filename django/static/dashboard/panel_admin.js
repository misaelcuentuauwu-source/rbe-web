// ════════════════════════════════════════
//  RBE — Panel Administrador
//  panel_admin.js
// ════════════════════════════════════════

// ── Estado global ──────────────────────
const tablaActual = { nombre:'', esquema:null, modo:null, pkName:null, pkValue:null };

let historialData     = [];
let historialFiltered = [];
let historialBase     = [];
let keData            = [];
let kgData            = null;
let kgView            = 'cards';
let kgTableCurrent    = 'boletos';
let kgCharts          = {};
let pasajerosActuales  = [];
let pasajerosViajeInfo = {};
let salidasData        = [];
let rutasDuracion      = {};
let _fotoFile          = null;
let gestionView        = 'tabla';
let gestionLastData    = null;
let gestionModo        = 'db';

// ── Helpers ────────────────────────────
const csrfHeaders = () => ({ 'Content-Type':'application/json', 'X-CSRFToken': CSRF });
const fmt   = dt => dt ? dt.replace('T',' ').substring(0,16) : '—';
const today = ()  => new Date().toISOString().split('T')[0];

function toLocalDatetimeString(date) {
  const pad = n => String(n).padStart(2,'0');
  return `${date.getFullYear()}-${pad(date.getMonth()+1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function parseDatetimeLocal(str) {
  if (!str) return null;
  const [datePart, timePart] = str.split('T');
  if (!datePart || !timePart) return null;
  const [y, mo, d]  = datePart.split('-').map(Number);
  const [h, mi]     = timePart.split(':').map(Number);
  return new Date(y, mo - 1, d, h, mi);
}

function toast(msg, tipo='ok') {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.className = `show ${tipo}`;
  setTimeout(() => t.className = '', 2800);
}

function semanaRango() {
  const now = new Date(), day = now.getDay();
  const lun = new Date(now); lun.setDate(now.getDate() + (day===0 ? -6 : 1-day));
  const dom = new Date(lun); dom.setDate(lun.getDate() + 6);
  return [lun.toISOString().split('T')[0], dom.toISOString().split('T')[0]];
}

function mesRango(m, y) {
  const anio = y || new Date().getFullYear();
  const mes  = parseInt(m || new Date().getMonth()+1);
  const ini  = `${anio}-${String(mes).padStart(2,'0')}-01`;
  const fin  = `${anio}-${String(mes).padStart(2,'0')}-${new Date(anio,mes,0).getDate()}`;
  return [ini, fin];
}

// ── Sidebar ────────────────────────────
const isMobile = () => window.innerWidth <= 767;

function toggleSidebar() {
  const sb   = document.getElementById('sidebar');
  const ov   = document.getElementById('sidebar-overlay');
  const main = document.getElementById('main');
  if (isMobile()) {
    const isOpen = sb.classList.contains('mobile-open');
    if (isOpen) { closeSidebarMobile(); }
    else {
      sb.classList.add('mobile-open');
      ov.classList.add('active');
      document.body.style.overflow = 'hidden';
    }
  } else {
    sb.classList.toggle('collapsed');
    const collapsed = sb.classList.contains('collapsed');
    main.style.marginLeft = collapsed
      ? 'var(--sidebar-w-collapsed)'
      : 'var(--sidebar-w)';
  }
}

function closeSidebarMobile() {
  document.getElementById('sidebar').classList.remove('mobile-open');
  document.getElementById('sidebar-overlay').classList.remove('active');
  document.body.style.overflow = '';
}

function afterNav() { if (isMobile()) closeSidebarMobile(); }

function toggleGestion() {
  const sub = document.getElementById('gestion-sub');
  sub.classList.toggle('open');
  document.getElementById('btn-gestion').querySelector('.label').textContent =
    sub.classList.contains('open') ? 'Gestión ▴' : 'Gestión ▾';
}

window.addEventListener('resize', () => {
  const main = document.getElementById('main');
  const sb   = document.getElementById('sidebar');
  if (!isMobile()) {
    sb.classList.remove('mobile-open');
    document.getElementById('sidebar-overlay').classList.remove('active');
    document.body.style.overflow = '';
    const collapsed = sb.classList.contains('collapsed');
    main.style.marginLeft = collapsed
      ? 'var(--sidebar-w-collapsed)'
      : 'var(--sidebar-w)';
  } else {
    main.style.marginLeft = '0';
  }
});

// ── Navegación ─────────────────────────
function showPage(id) {
  document.querySelectorAll('.page').forEach(p => p.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
  document.getElementById('page-'+id)?.classList.add('active');
  document.getElementById('topbar-title').textContent = {
    'kpi-generales'   : 'KPIs Generales',
    'kpi-especificos' : 'KPIs Específicos',
    'reporte-ventas'  : 'Reporte de Ventas',
    'salidas'         : 'Salidas',
    'historial'       : 'Historial de Viajes',
    'gestion'         : 'Gestión',
    'configuracion'   : 'Configuración'
  }[id] || id;
  // Ocultar FAB modo asistido cuando no estamos en Gestión→viaje
  if (id !== 'gestion') {
    const fab = document.getElementById('fab-modo-asistido');
    if (fab) fab.style.display = 'none';
  }
  if (id==='salidas')         cargarSalidas();
  if (id==='historial')       cargarHistorial();
  if (id==='kpi-generales')   cargarKpiGenerales();
  if (id==='reporte-ventas')  rvIniciarOpciones();
  if (id==='kpi-especificos') {
    const t = document.getElementById('ke-tipo').value;
    keView = (t === 'ventas') ? 'cards' : 'tabla';
    document.getElementById('ke-view-btns').style.display = '';
    document.getElementById('ke-vbtn-cards').classList.toggle('active', keView === 'cards');
    document.getElementById('ke-vbtn-tabla').classList.toggle('active', keView === 'tabla');
    cargarKpiOpciones(); cargarKpiEspecificos(false);
  }
  if (id==='configuracion')   cargarConfig();
  afterNav();
}

function showGestion(tabla) {
  showPage('gestion');
  document.getElementById('gestion-title').textContent =
    'Gestión — ' + tabla.charAt(0).toUpperCase() + tabla.slice(1);
  tablaActual.nombre = tabla;
  if (!TABLAS_CON_LEGIBLE.has(tabla)) gestionModo = 'db';
  // Ocultar FAB si no es viaje; recargarGestion lo mostrará si aplica
  const fab = document.getElementById('fab-modo-asistido');
  if (fab) fab.style.display = 'none';
  recargarGestion();
}

// ════ KPI GENERALES ════════════════════

function kgRangoChange() {
  const r = document.getElementById('kg-rango').value;
  document.getElementById('kg-dia-wrap').style.display  = r==='dia' ? '' : 'none';
  document.getElementById('kg-mes-wrap').style.display  = r==='mes' ? '' : 'none';
  document.getElementById('kg-anio-wrap').style.display = r==='mes' ? '' : 'none';
}

function kgGetRango() {
  const r = document.getElementById('kg-rango').value;
  if (r==='dia')    { const d = document.getElementById('kg-fecha').value||today(); return [d,d]; }
  if (r==='semana') return semanaRango();
  return mesRango(document.getElementById('kg-mes').value, document.getElementById('kg-anio').value);
}

async function cargarKpiGenerales() {
  const [desde,hasta] = kgGetRango();
  kgData = await fetch(`/api/kpi/generales/?desde=${desde}&hasta=${hasta}`).then(r=>r.json());
  renderKgView();
}

function kgSetView(v) {
  kgView = v;
  ['cards','charts','table'].forEach(x => {
    document.getElementById(`kg-view-${x}`).style.display = x===v ? '' : 'none';
    document.getElementById(`vbtn-${x}`).classList.toggle('active', x===v);
  });
  if (kgData) renderKgView();
}

function renderKgView() {
  if (kgView==='cards')  renderKgCards();
  if (kgView==='charts') renderKgCharts();
  if (kgView==='table')  renderKgTable(kgTableCurrent);
}

function renderTop5Cards(id, data, lf, cf='total') {
  const el = document.getElementById(id);
  if (!data?.length) {
    el.innerHTML='<div style="color:var(--muted);font-size:13px;padding:8px 0">Sin datos</div>';
    return;
  }
  el.innerHTML = data.map((r,i)=>`
    <div class="kpi-item" style="animation-delay:${i*.06}s">
      <span class="kpi-item-label">${i+1}. ${r[lf]??r[cf]??''}</span>
      <span class="kpi-item-count">${r[cf]??0}</span>
    </div>`).join('');
}

function renderKgCards() {
  renderTop5Cards('kg-boletos',    kgData.boletos,    'ciudad',      'total');
  renderTop5Cards('kg-conductores',kgData.conductores,'nombre',      'total');
  renderTop5Cards('kg-autobuses',  kgData.autobuses,  'autobus_num', 'total');
  renderTop5Cards('kg-destinos',   kgData.destinos,   'nombre',      'total');
  renderTop5Cards('kg-origenes',   kgData.origenes,   'nombre',      'total');
  renderEcoCards();
}

function pesos(n) {
  const num = parseFloat(n) || 0;
  return '$' + num.toLocaleString('es-MX', { minimumFractionDigits:2, maximumFractionDigits:2 });
}

function renderEcoCards() {
  const eco = kgData.eco_resumen && kgData.eco_resumen[0];
  if (!eco) return;

  document.getElementById('eco-total').textContent    = pesos(eco.total_recaudado);
  document.getElementById('eco-txn').textContent      = `${eco.num_transacciones ?? 0} transacciones`;
  document.getElementById('eco-promedio').textContent      = pesos(eco.promedio_boleto);
  document.getElementById('eco-boletos-count').textContent = `${eco.num_boletos ?? 0} boletos vendidos`;

  const totEf  = parseFloat(eco.total_efectivo) || 0;
  const totTj  = parseFloat(eco.total_tarjeta)  || 0;
  const totAll = totEf + totTj || 1;
  const pctEf  = Math.round(totEf / totAll * 100);
  const pctTj  = 100 - pctEf;

  document.getElementById('eco-efectivo').textContent        = pesos(totEf);
  document.getElementById('eco-tarjeta').textContent         = pesos(totTj);
  document.getElementById('eco-bar-efectivo').style.width    = pctEf + '%';
  document.getElementById('eco-bar-tarjeta').style.width     = pctTj + '%';
  document.getElementById('eco-split-pct').textContent =
    `Efectivo ${pctEf}%  ·  Tarjeta ${pctTj}%  ·  (${eco.txn_efectivo ?? 0} / ${eco.txn_tarjeta ?? 0} transacciones)`;

  const taqs   = kgData.eco_taquilleros || [];
  const taqEl  = document.getElementById('kg-taquilleros');
  if (!taqs.length) {
    taqEl.innerHTML = '<div style="color:var(--muted);font-size:13px;padding:8px 0">Sin datos para este periodo</div>';
    return;
  }
  const maxTotal  = parseFloat(taqs[0].total) || 1;
  const rankClass = i => ['r1','r2','r3','rn','rn'][i] || 'rn';
  taqEl.innerHTML = `
    <table class="eco-taq-table">
      <thead><tr>
        <th>#</th><th>Taquillero</th>
        <th style="text-align:right">Boletos</th>
        <th style="text-align:right">Transacciones</th>
        <th style="text-align:right">Total vendido</th>
        <th></th>
      </tr></thead>
      <tbody>
        ${taqs.map((t, i) => {
          const pct = Math.round(parseFloat(t.total) / maxTotal * 100);
          return `<tr style="animation:slideIn .3s ease ${i*.06}s both">
            <td><span class="eco-taq-rank ${rankClass(i)}">${i+1}</span></td>
            <td style="font-weight:700">${t.nombre ?? '—'}</td>
            <td style="text-align:right">${t.boletos ?? 0}</td>
            <td style="text-align:right">${t.transacciones ?? 0}</td>
            <td style="text-align:right" class="eco-taq-total">${pesos(t.total)}</td>
            <td class="eco-taq-bar-wrap">
              <div class="eco-taq-mini-bar">
                <div class="eco-taq-mini-fill" style="width:${pct}%"></div>
              </div>
            </td>
          </tr>`;
        }).join('')}
      </tbody>
    </table>`;
}

// ── Gráficas ───────────────────────────
const PIE_COLORS = ['#ed7237','#1181c3','#52b788','#f4a261','#264653','#e9c46a','#2a9d8f'];

function destroyChart(id) {
  if (kgCharts[id]) { kgCharts[id].destroy(); delete kgCharts[id]; }
}

function makeChart(cid, type, labels, values) {
  destroyChart(cid);
  const ctx = document.getElementById(cid);
  if (!ctx || !labels.length) return;
  const isPie = type==='doughnut';
  kgCharts[cid] = new Chart(ctx, {
    type,
    data:{ labels, datasets:[{ data:values, backgroundColor:PIE_COLORS,
      borderColor:isPie?'#fff':'transparent', borderWidth:isPie?3:0, borderRadius:isPie?0:6 }] },
    options:{ responsive:true, maintainAspectRatio:false,
      animation:{duration:700, easing:'easeOutQuart'},
      plugins:{ legend:{display:isPie, position:'bottom',
        labels:{font:{family:'DM Sans',size:11,weight:'700'}, padding:12, color:'#1a2b3c'}},
        tooltip:{callbacks:{label:c=>` ${c.label}: ${c.parsed.y??c.parsed}`}} },
      scales: isPie ? {} : {
        x:{grid:{display:false}, ticks:{font:{family:'DM Sans',size:11}, color:'#6b8fa8'}},
        y:{grid:{color:'#e2e8f0'}, ticks:{font:{family:'DM Sans',size:11}, color:'#6b8fa8'}, beginAtZero:true}
      }
    }
  });
}

function renderKgCharts() {
  const d = kgData;
  makeChart('ch-boletos',    'doughnut', d.boletos.map(r=>r.ciudad),                  d.boletos.map(r=>r.total));
  makeChart('ch-conductores','bar',      d.conductores.map(r=>r.nombre),              d.conductores.map(r=>r.total));
  makeChart('ch-autobuses',  'bar',      d.autobuses.map(r=>`Bus #${r.autobus_num}`), d.autobuses.map(r=>r.total));
  makeChart('ch-destinos',   'doughnut', d.destinos.map(r=>r.nombre),                 d.destinos.map(r=>r.total));
  makeChart('ch-origenes',   'bar',      d.origenes.map(r=>r.nombre),                 d.origenes.map(r=>r.total));
}

// ── Tabla KG ───────────────────────────
const KG_CFG = {
  boletos:    {h:['#','Ciudad destino','Boletos vendidos','Barra'], lf:'ciudad',     cf:'total'},
  conductores:{h:['#','Conductor','Viajes realizados','Barra'],    lf:'nombre',     cf:'total'},
  autobuses:  {h:['#','Autobús #','Viajes','Barra'],               lf:'autobus_num',cf:'total'},
  destinos:   {h:['#','Ciudad destino','Viajes','Barra'],          lf:'nombre',     cf:'total'},
  origenes:   {h:['#','Ciudad origen','Viajes','Barra'],           lf:'nombre',     cf:'total'},
};

function kgTableTab(key, btn) {
  kgTableCurrent = key;
  document.querySelectorAll('.kg-tab').forEach(b=>b.classList.remove('active'));
  btn.classList.add('active');
  if (kgData) renderKgTable(key);
}

function renderKgTable(key) {
  const cfg = KG_CFG[key], rows = kgData[key]||[], max = rows[0]?.[cfg.cf]||1;
  document.getElementById('kg-full-thead').innerHTML =
    `<tr>${cfg.h.map(h=>`<th>${h}</th>`).join('')}</tr>`;
  const tb = document.getElementById('kg-full-tbody');
  if (!rows.length) {
    tb.innerHTML=`<tr><td colspan="4" style="text-align:center;padding:24px;color:var(--muted)">Sin datos</td></tr>`;
    return;
  }
  tb.innerHTML = rows.map((r,i) => {
    const pct = Math.round((r[cfg.cf]??0)/max*100);
    const rc  = i===0?'rank-1':i===1?'rank-2':i===2?'rank-3':'rank-n';
    return `<tr style="animation:slideIn .3s ease ${i*.04}s both">
      <td><span class="rank-badge ${rc}">${i+1}</span></td>
      <td style="font-weight:700">${r[cfg.lf]??'—'}</td>
      <td style="font-weight:800;color:var(--naranja)">${r[cfg.cf]??0}</td>
      <td style="min-width:120px"><div class="bar-cell">
        <div class="mini-bar-wrap"><div class="mini-bar" style="width:${pct}%"></div></div>
        <span style="font-size:11px;color:var(--muted);min-width:28px">${pct}%</span>
      </div></td>
    </tr>`;
  }).join('');
}

function exportarKgCSV() {
  if (!kgData) { toast('No hay datos','err'); return; }
  const cfg  = KG_CFG[kgTableCurrent], rows = kgData[kgTableCurrent]||[];
  if (!rows.length) { toast('Sin datos','err'); return; }
  const csv  = [cfg.h[1]+','+cfg.h[2],
    ...rows.map(r=>`"${r[cfg.lf]??''}","${r[cfg.cf]??0}"`)].join('\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));
  a.download = `kpi_generales_${kgTableCurrent}.csv`;
  a.click();
  toast('CSV exportado');
}

// ════ KPI ESPECÍFICOS ══════════════════

function keScopeChange() {
  const s = document.getElementById('ke-scope').value;
  document.getElementById('ke-dia-wrap').style.display  = s==='dia' ? '' : 'none';
  document.getElementById('ke-mes-wrap').style.display  = s==='mes' ? '' : 'none';
  document.getElementById('ke-anio-wrap').style.display = s==='mes' ? '' : 'none';
}

function keTipoChange() {
  const t = document.getElementById('ke-tipo').value;
  document.getElementById('ke-conductor-wrap').style.display = t==='conductor' ? '' : 'none';
  document.getElementById('ke-autobus-wrap').style.display   = t==='autobus'   ? '' : 'none';
  document.getElementById('ke-ciudad-wrap').style.display    = t==='ciudad'    ? '' : 'none';
  document.getElementById('ke-ventas-wrap-filtros').style.display = t==='ventas' ? '' : 'none';
  // Toggle visible para todos los tipos; default según tipo
  document.getElementById('ke-view-btns').style.display = '';
  keView = (t === 'ventas') ? 'cards' : 'tabla';
  document.getElementById('ke-vbtn-cards').classList.toggle('active', keView === 'cards');
  document.getElementById('ke-vbtn-tabla').classList.toggle('active', keView === 'tabla');
  if (t !== 'ventas') {
    document.getElementById('ke-ventas-sujeto-wrap').style.display    = 'none';
    document.getElementById('ke-ventas-ruta-wrap').style.display       = 'none';
    document.getElementById('ke-ventas-taquillero-wrap').style.display = 'none';
  }
  if (t === 'ventas') {
    const tipoSuj = document.getElementById('ke-ventas-sujeto-tipo').value;
    const items = tipoSuj === 'taquillero'
      ? (window._keFiltros?.taquilleros || [])
      : (window._keFiltros?.clientes    || []);
    document.getElementById('ke-ventas-sujeto-wrap').style.display = items.length ? '' : 'none';
    document.getElementById('ke-ventas-ruta-wrap').style.display   = (window._keFiltros?.rutas?.length) ? '' : 'none';
    document.getElementById('ke-ventas-taquillero-wrap').style.display = 'none';
  }
  cargarKpiEspecificos(false);
}

async function cargarKpiOpciones() {
  const d = await fetch('/api/kpi/filtros/').then(r=>r.json());
  window._keFiltros = d;
  fillSelect('ke-conductor', d.conductores, 'Todos');
  fillSelect('ke-autobus',   d.autobuses,   'Todos');
  fillSelect('ke-ciudad',    d.ciudades,    'Todas');
  const selId = document.getElementById('ke-ventas-sujeto-id');
  selId.innerHTML = '<option value="">— Todos —</option>' +
    (d.taquilleros||[]).map(i => `<option value="${i.value}">${i.label}</option>`).join('');
  const selRuta = document.getElementById('ke-ventas-ruta');
  selRuta.innerHTML = '<option value="">— Todas —</option>' +
    (d.rutas||[]).map(i => `<option value="${i.value}">${i.label}</option>`).join('');
  const selTaq = document.getElementById('ke-ventas-taquillero');
  selTaq.innerHTML = '<option value="">— Todos —</option>' +
    (d.taquilleros||[]).map(i => `<option value="${i.value}">${i.label}</option>`).join('');
}

function fillSelect(id, items, ph) {
  const sel  = document.getElementById(id), prev = sel.value;
  sel.innerHTML = `<option value="">${ph}</option>` +
    items.map(i=>`<option value="${i.value}">${i.label}</option>`).join('');
  sel.value = prev;
}

function keGetRango() {
  const s = document.getElementById('ke-scope').value;
  if (s==='todos')  return [null,null];
  if (s==='dia')    { const d = document.getElementById('ke-fecha').value||today(); return [d,d]; }
  if (s==='semana') return semanaRango();
  return mesRango(document.getElementById('ke-mes').value, document.getElementById('ke-anio').value);
}

async function cargarKpiEspecificos(aplicar) {
  const tipo = document.getElementById('ke-tipo').value;
  const [desde,hasta] = keGetRango();
  const c  = document.getElementById('ke-conductor').value;
  const a  = document.getElementById('ke-autobus').value;
  const ci = document.getElementById('ke-ciudad').value;
  let url  = `/api/kpi/especificos/?tipo=${tipo}&aplicar=${aplicar?1:0}`;
  if (desde) url += `&desde=${desde}&hasta=${hasta}`;
  if (c)  url += `&conductor=${c}`;
  if (a)  url += `&autobus=${a}`;
  if (ci) url += `&ciudad=${ci}`;
  if (tipo === 'ventas') {
    const st  = document.getElementById('ke-ventas-sujeto-tipo').value;
    const si  = document.getElementById('ke-ventas-sujeto-id').value;
    const ri  = document.getElementById('ke-ventas-ruta').value;
    if (st) url += `&sujeto_tipo=${st}`;
    if (si) url += `&sujeto_id=${si}`;
    if (ri) url += `&ruta_id=${ri}`;
    // ── CAMBIO 2: ya no enviamos vendedor_id porque el filtro taquillero
    //    no existe en modo cliente. En modo taquillero sujeto_id ya lo cubre. ──
  }
  const d = await fetch(url).then(r=>r.json());
  keData  = d.rows;
  renderKeTablo(tipo, d.rows);
}

// ════ KPI VENTAS — tipo de usuario ══════════════

function keVentasSujetoTipoChange() {
  const tipo = document.getElementById('ke-ventas-sujeto-tipo').value;
  const selItems = document.getElementById('ke-ventas-sujeto-id');
  const items = tipo === 'taquillero'
    ? (window._keFiltros?.taquilleros || [])
    : (window._keFiltros?.clientes    || []);
  selItems.innerHTML = '<option value="">— Todos —</option>' +
    items.map(i => `<option value="${i.value}">${i.label}</option>`).join('');
  const tipoActivo = document.getElementById('ke-tipo').value;
  document.getElementById('ke-ventas-sujeto-wrap').style.display = (items.length && tipoActivo === 'ventas') ? '' : 'none';
  // ── CAMBIO 3: el filtro taquillero NUNCA se muestra, independientemente del tipo ──
  document.getElementById('ke-ventas-taquillero-wrap').style.display = 'none';
  // Resetear selects al cambiar modo
  document.getElementById('ke-ventas-sujeto-id').value  = '';
  _keUnlockSujetoFilter();
  cargarKpiEspecificos(false);
}

// ── Cambio de sujeto individual ──────────────────────────────────────────────
function keOnSujetoChange() {
  cargarKpiEspecificos(false);
}

// ── keOnTaquilleroChange ya no tiene efecto visible pero la dejamos
//    por si el HTML la referencia en algún onchange residual ──
function keOnTaquilleroChange() {
  // no-op: el filtro taquillero está oculto permanentemente en modo cliente
}

// ── Desbloquear el select de sujeto (sin exclusión mutua ya que taquillero no existe) ──
function _keUnlockSujetoFilter() {
  const siEl = document.getElementById('ke-ventas-sujeto-id');
  siEl.disabled = false; siEl.style.opacity = ''; siEl.title = '';
}

// Mantenemos _keApplyMutualExclusion y _keUnlockBothFilters como stubs
// por si quedaron referencias en el HTML, pero ya no hacen nada relevante.
function _keApplyMutualExclusion(origen) {
  // no-op: la exclusión mutua ya no aplica porque el filtro taquillero está oculto
}
function _keUnlockBothFilters() {
  _keUnlockSujetoFilter();
}

const _MESES_CORTOS = ['','Ene','Feb','Mar','Abr','May','Jun','Jul','Ago','Sep','Oct','Nov','Dic'];

function _fmtVentaFecha(s) {
  try {
    const d = new Date(s);
    const pad = n => String(n).padStart(2,'0');
    return `${d.getDate()} ${_MESES_CORTOS[d.getMonth()+1]} ${d.getFullYear()}  ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  } catch(_) { return s ? s.substring(0,10) : '—'; }
}

let keView = 'tabla'; // default tabla; ventas arranca en cards

function setKeView(v) {
  keView = v;
  document.getElementById('ke-vbtn-cards').classList.toggle('active', v === 'cards');
  document.getElementById('ke-vbtn-tabla').classList.toggle('active', v === 'tabla');
  renderKeTablo(document.getElementById('ke-tipo').value, keData);
}

// alias legacy para no romper nada que lo llame desde otro lado
function setKeVentasView(v) { setKeView(v); }

function renderKeTablo(tipo, rows) {
  if (tipo === 'ventas') { renderKeVentas(rows); return; }

  if (keView === 'cards') {
    document.getElementById('ke-tabla-wrap').style.display = 'none';
    document.getElementById('ke-ventas-wrap').style.display = '';
    document.getElementById('ke-ventas-tabla-wrap').style.display = 'none';
    document.getElementById('ke-info-text').textContent = `Resultados: ${rows.length} registro(s)`;
    const wrap = document.getElementById('ke-ventas-cards');
    if (!rows.length) {
      wrap.innerHTML = `<div class="empty-state"><div class="empty-icon">📋</div><p>Sin datos para los filtros seleccionados.</p></div>`;
      return;
    }
    if      (tipo === 'boletos')   wrap.innerHTML = renderKeBoletoCards(rows);
    else if (tipo === 'conductor') wrap.innerHTML = renderKeConductorCards(rows);
    else if (tipo === 'autobus')   wrap.innerHTML = renderKeAutobusCards(rows);
    else                           wrap.innerHTML = renderKeCiudadCards(rows);
    return;
  }

  // Vista tabla (comportamiento original)
  document.getElementById('ke-ventas-wrap').style.display = 'none';
  const tbl = document.getElementById('ke-tabla');
  let h=[], map;
  if (tipo==='boletos') {
    h   = ['Viaje','F. salida','Origen','Destino','Autobús','Vendidos','Disponibles'];
    map = r=>[r.trip_id,fmt(r.departure),r.origin_city,r.dest_city,r.bus_number,r.vendidos,r.disponibles];
  } else if (tipo==='conductor') {
    h   = ['Conductor','Viaje','Salida','Llegada','Origen','Destino','Autobús'];
    map = r=>[`${r.con_nombre||''} ${r.con_ap1||''}`,r.trip_id,fmt(r.departure),fmt(r.arrival),r.origin_city,r.dest_city,r.bus_number];
  } else if (tipo==='autobus') {
    h   = ['Número','Matrícula','Marca','Modelo','Año','Asientos'];
    map = r=>[r.bus_number,r.placas,r.marca_nombre,r.modelo_nombre,r.modelo_ano,r.numasientos];
  } else {
    h   = ['Ciudad','Salida','Viaje','Destino','Autobús','Matrícula','Operador'];
    map = r=>[r.ciudad,fmt(r.salida),r.viaje,r.destino,r.autobus,r.matricula,r.operador];
  }
  document.getElementById('ke-tabla-wrap').style.display = '';
  tbl.querySelector('thead').innerHTML = `<tr>${h.map(x=>`<th>${x}</th>`).join('')}</tr>`;
  tbl.querySelector('tbody').innerHTML =
    rows.map(r=>`<tr>${map(r).map(v=>`<td>${v??'—'}</td>`).join('')}</tr>`).join('') ||
    `<tr><td colspan="${h.length}" style="text-align:center;color:var(--muted);padding:24px">Sin datos</td></tr>`;
  document.getElementById('ke-info-text').textContent = `Resultados: ${rows.length} registro(s)`;
}

/* ── Tarjetas: Boletos ── */
function renderKeBoletoCards(rows) {
  return `<div class="kv-grid">${rows.map((r,i) => {
    const pct = r.vendidos != null && (r.vendidos + r.disponibles) > 0
      ? Math.round(r.vendidos / (r.vendidos + r.disponibles) * 100) : 0;
    const pillClass = pct >= 90 ? 'warn' : pct >= 60 ? 'accent' : 'ok';
    return `
    <div class="kv-card ke-card-boleto" style="animation-delay:${Math.min(i*.04,.5)}s">
      <div class="ke-card-header">
        <div>
          <div class="ke-card-ruta">
            <span class="ke-orig">● ${r.origin_city||'—'}</span>
            <span class="ke-arr">┄▶</span>
            <span class="ke-dest">📍 ${r.dest_city||'—'}</span>
          </div>
          <div style="font-size:11px;color:var(--muted);margin-top:3px">🚌 ${r.bus_number||'—'} &nbsp;·&nbsp; 🕐 ${fmt(r.departure)}</div>
        </div>
        <div class="ke-card-stat">
          <span class="ke-stat-num">${r.vendidos??'—'}</span>
          <span class="ke-stat-label">vendidos</span>
        </div>
      </div>
      <div class="kv-card-sep"></div>
      <div class="ke-card-meta">
        <span class="ke-meta-pill ${pillClass}">🎟 ${r.vendidos??0} / ${(r.vendidos??0)+(r.disponibles??0)} asientos</span>
        <span class="ke-meta-pill">🪑 ${r.disponibles??'—'} libres</span>
        <span class="ke-meta-pill accent">ID #${r.trip_id||'—'}</span>
      </div>
      <div class="ke-capacity-bar">
        <div class="ke-capacity-fill" style="width:${pct}%"></div>
      </div>
    </div>`;
  }).join('')}</div>`;
}

/* ── Tarjetas: Conductor ── */
function renderKeConductorCards(rows) {
  return `<div class="kv-grid">${rows.map((r,i) => {
    const nombre = `${r.con_nombre||''} ${r.con_ap1||''}`.trim() || '—';
    return `
    <div class="kv-card ke-card-conductor" style="animation-delay:${Math.min(i*.04,.5)}s">
      <div style="display:flex;align-items:center;gap:12px">
        <div class="ke-con-avatar">🧑‍✈️</div>
        <div class="ke-con-info">
          <div class="ke-con-name">${nombre}</div>
          <div class="ke-con-id">Viaje #${r.trip_id||'—'}</div>
        </div>
      </div>
      <div class="kv-card-sep"></div>
      <div class="ke-card-ruta">
        <span class="ke-orig">● ${r.origin_city||'—'}</span>
        <span class="ke-arr">┄▶</span>
        <span class="ke-dest">📍 ${r.dest_city||'—'}</span>
      </div>
      <div class="ke-card-meta">
        <span class="ke-meta-pill accent">🚌 ${r.bus_number||'—'}</span>
        <span class="ke-meta-pill">🕐 ${fmt(r.departure)}</span>
        <span class="ke-meta-pill">🏁 ${fmt(r.arrival)}</span>
      </div>
    </div>`;
  }).join('')}</div>`;
}

/* ── Tarjetas: Autobús ── */
function renderKeAutobusCards(rows) {
  return `<div class="kv-grid">${rows.map((r,i) => `
    <div class="kv-card ke-card-autobus" style="animation-delay:${Math.min(i*.04,.5)}s">
      <div style="display:flex;align-items:flex-start;justify-content:space-between;gap:12px">
        <div>
          <div class="ke-bus-num">#${r.bus_number||'—'}</div>
          <div class="ke-bus-placas">${r.placas||'sin placa'}</div>
        </div>
        <div class="ke-meta-pill accent" style="margin-top:4px">🪑 ${r.numasientos||'—'} asientos</div>
      </div>
      <div class="kv-card-sep"></div>
      <div class="ke-card-meta">
        <span class="ke-meta-pill">🚗 ${r.marca_nombre||'—'}</span>
        <span class="ke-meta-pill">📋 ${r.modelo_nombre||'—'}</span>
        <span class="ke-meta-pill">📅 ${r.modelo_ano||'—'}</span>
      </div>
    </div>`).join('')}</div>`;
}

/* ── Tarjetas: Ciudad ── */
function renderKeCiudadCards(rows) {
  return `<div class="kv-grid">${rows.map((r,i) => `
    <div class="kv-card ke-card-ciudad" style="animation-delay:${Math.min(i*.04,.5)}s">
      <div style="display:flex;align-items:center;gap:12px">
        <div class="ke-ciudad-icon">🏙️</div>
        <div>
          <div class="ke-ciudad-name">${r.ciudad||'—'}</div>
          <div style="font-size:11px;color:var(--muted);margin-top:2px">Viaje #${r.viaje||'—'}</div>
        </div>
      </div>
      <div class="kv-card-sep"></div>
      <div class="ke-card-meta">
        <span class="ke-meta-pill accent">🕐 ${fmt(r.salida)}</span>
        <span class="ke-meta-pill">📍 → ${r.destino||'—'}</span>
        <span class="ke-meta-pill">🚌 ${r.autobus||'—'}</span>
      </div>
      <div class="ke-card-meta">
        <span class="ke-meta-pill">🪪 ${r.matricula||'—'}</span>
        <span class="ke-meta-pill">👤 ${r.operador||'—'}</span>
      </div>
    </div>`).join('')}</div>`;
}

function renderKeVentas(rows) {
  document.getElementById('ke-tabla-wrap').style.display = 'none';
  document.getElementById('ke-ventas-wrap').style.display = '';
  const wrap = document.getElementById('ke-ventas-cards');
  const tipoSujeto = document.getElementById('ke-ventas-sujeto-tipo').value;
  const esCliente  = tipoSujeto === 'cliente';
  const total = rows.length;

  document.getElementById('ke-info-text').textContent = esCliente
    ? `Resultados: ${total} compra(s)`
    : `Resultados: ${total} venta(s)`;

  if (!rows.length) {
    wrap.innerHTML = `<div class="empty-state"><div class="empty-icon">🧾</div><p>${esCliente ? 'Este cliente no tiene compras registradas.' : 'Sin ventas para los filtros seleccionados.'}</p></div>`;
    document.getElementById('ke-ventas-tabla-wrap').style.display = 'none';
    return;
  }

  const totalMonto = rows.reduce((s,r) => s + (parseFloat(r.monto)||0), 0);
  const totalPax   = rows.reduce((s,r) => s + (parseInt(r.num_pasajeros)||0), 0);

  const labelVentas  = esCliente ? 'Compras'      : 'Ventas';
  const labelPax     = esCliente ? 'Boletos'       : 'Pasajeros';
  const labelTotal   = esCliente ? 'Total gastado' : 'Total recaudado';

  const resumenHtml = `
    <div class="kv-resumen">
      <div class="kv-resumen-item">
        <span class="kv-resumen-label">${labelTotal}</span>
        <span class="kv-resumen-value kv-verde">${pesos(totalMonto)}</span>
      </div>
      <div class="kv-resumen-item">
        <span class="kv-resumen-label">${labelVentas}</span>
        <span class="kv-resumen-value">${rows.length}</span>
      </div>
      <div class="kv-resumen-item">
        <span class="kv-resumen-label">${labelPax}</span>
        <span class="kv-resumen-value">${totalPax}</span>
      </div>
      <div class="kv-resumen-item">
        <span class="kv-resumen-label">Promedio</span>
        <span class="kv-resumen-value">${pesos(rows.length ? totalMonto/rows.length : 0)}</span>
      </div>
    </div>`;

  if (keView === 'tabla') {
    wrap.innerHTML = resumenHtml;
    document.getElementById('ke-ventas-tabla-wrap').style.display = '';
    const tbl = document.getElementById('ke-ventas-tabla');
    const hCols = ['Folio','Fecha venta','Viaje (salida)','Origen','Destino','Estado','Boletos','Método pago','Vendedor','Monto (MXN)'];
    tbl.querySelector('thead').innerHTML = `<tr>${hCols.map(h=>`<th>${h}</th>`).join('')}</tr>`;
    tbl.querySelector('tbody').innerHTML = rows.map(v => {
      const monto = parseFloat(v.monto||0).toFixed(2);
      const vendedor = v.vendedor_nombre || 'App';
      return `<tr>
        <td>#${v.folio}</td>
        <td>${(v.fecha||'').substring(0,16).replace('T',' ')}</td>
        <td>${_fmtVentaFecha(v.hora_salida)}</td>
        <td>${v.origen||'—'}</td>
        <td>${v.destino||'—'}</td>
        <td>${v.estado||'—'}</td>
        <td style="text-align:center">${v.num_pasajeros}</td>
        <td>${v.metodo_pago||'—'}</td>
        <td>${vendedor}</td>
        <td style="text-align:right;font-weight:600">$${monto}</td>
      </tr>`;
    }).join('') || `<tr><td colspan="10" style="text-align:center;color:var(--muted);padding:24px">Sin datos</td></tr>`;
  } else {
    document.getElementById('ke-ventas-tabla-wrap').style.display = 'none';
    wrap.innerHTML = resumenHtml + `
    <div class="kv-grid">
      ${rows.map((v,i) => {
        const esTarjeta = (v.metodo_pago||'').toLowerCase().includes('tarjeta');
        const estadoClass = {
          'disponible':'kv-estado-disp','en ruta':'kv-estado-ruta',
          'finalizado':'kv-estado-fin','cancelado':'kv-estado-can'
        }[(v.estado||'').toLowerCase()] || 'kv-estado-otro';
        const monto = parseFloat(v.monto||0).toFixed(2);
        const vendedorChip = (!esCliente && v.vendedor_nombre)
          ? `<span class="kv-chip kv-chip-vend">👤 ${v.vendedor_nombre}</span>`
          : '';
        return `
        <div class="kv-card" style="animation-delay:${Math.min(i*.04,.5)}s">
          <div class="kv-card-top">
            <span class="kv-folio">Folio #${v.folio}</span>
            ${v.estado ? `<span class="kv-estado ${estadoClass}">${v.estado}</span>` : ''}
            <span class="kv-fecha-venta">${_fmtVentaFecha(v.fecha)}</span>
          </div>
          <div class="kv-ruta">
            <span class="kv-origen">● ${v.origen||'—'}</span>
            <span class="kv-flecha">┄┄┄▶</span>
            <span class="kv-destino">📍 ${v.destino||'—'}</span>
          </div>
          <div class="kv-fechas">
            <span>${esCliente ? '🛒' : '🧾'} ${esCliente ? 'Compra' : 'Venta'}: <b>${(v.fecha||'').substring(0,10)}</b></span>
            <span>🚌 Viaje: <b>${_fmtVentaFecha(v.hora_salida)}</b></span>
          </div>
          <div class="kv-card-sep"></div>
          <div class="kv-card-bottom">
            <div class="kv-chips">
              <span class="kv-chip">👥 ${v.num_pasajeros} ${esCliente ? 'boleto(s)' : 'pax'}</span>
              <span class="kv-chip">${esTarjeta ? '💳' : '💵'} ${v.metodo_pago}</span>
              ${vendedorChip}
            </div>
            <div class="kv-monto">
              <span class="kv-monto-num">$${monto}</span>
              <span class="kv-monto-cur">MXN</span>
            </div>
          </div>
        </div>`;
      }).join('')}
    </div>`;
  }
}

function exportarCSV() {
  if (!keData.length) { toast('No hay datos', 'err'); return; }
  const tipo = document.getElementById('ke-tipo').value;
  let csv, filename;

  if (tipo === 'ventas') {
    const tipoSujeto = document.getElementById('ke-ventas-sujeto-tipo').value;
    const esCliente  = tipoSujeto === 'cliente';
    const cols = [
      { key: 'folio',          label: 'Folio' },
      { key: 'fecha',          label: 'Fecha de venta' },
      { key: 'hora_salida',    label: 'Fecha/hora del viaje' },
      { key: 'origen',         label: 'Origen' },
      { key: 'destino',        label: 'Destino' },
      { key: 'estado',         label: 'Estado del viaje' },
      { key: 'num_pasajeros',  label: 'Boletos' },
      { key: 'metodo_pago',    label: 'Método de pago' },
      { key: 'vendedor_nombre',label: esCliente ? 'Vendedor' : 'Taquillero' },
      { key: 'monto',          label: 'Monto (MXN)' },
    ];
    const esc = v => `"${(v??'').toString().replace(/"/g,'""')}"`;
    csv = [
      cols.map(c => esc(c.label)).join(','),
      ...keData.map(r => cols.map(c => esc(r[c.key])).join(','))
    ].join('\r\n');
    const desde = document.getElementById('ke-fecha')?.value || '';
    const rutaSel = document.getElementById('ke-ventas-ruta');
    const rutaLabel = rutaSel?.options[rutaSel.selectedIndex]?.text || '';
    const sujetoSel = document.getElementById('ke-ventas-sujeto-id');
    const sujetoLabel = sujetoSel?.options[sujetoSel.selectedIndex]?.text || '';
    const parts = ['ventas'];
    if (desde) parts.push(desde);
    if (rutaLabel && rutaLabel !== '— Todas —') parts.push(rutaLabel.replace(/[^a-zA-Z0-9áéíóúÁÉÍÓÚ ]/g,'-').trim());
    if (sujetoLabel && sujetoLabel !== '— Todos —') parts.push(sujetoLabel.split(' ')[0]);
    filename = parts.join('_').replace(/\s+/g,'_') + '.csv';
  } else {
    const hd = Object.keys(keData[0]);
    csv = [hd.join(','),
      ...keData.map(r => hd.map(h => `"${(r[h]??'').toString().replace(/"/g,'""')}"`).join(','))
    ].join('\r\n');
    filename = `kpi_${tipo}.csv`;
  }

  const bom = new Uint8Array([0xEF, 0xBB, 0xBF]);
  const blob = new Blob([bom, csv], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = filename;
  a.click();
  toast('CSV exportado');
}

// ════ SALIDAS ══════════════════════════

async function cargarSalidas() {
  document.getElementById('salidas-container').innerHTML = '<span class="spinner"></span>';
  const d  = await fetch('/api/salidas/').then(r=>r.json());
  salidasData = d.rows || [];
  const todasCiudades = [...new Set([
    ...salidasData.map(r=>r.origen_ciudad),
    ...salidasData.map(r=>r.destino_ciudad)
  ].filter(Boolean))].sort();
  const selOrig = document.getElementById('sal-origen');
  const selDest = document.getElementById('sal-destino');
  selOrig.innerHTML = '<option value="">-- Todas --</option>' + todasCiudades.map(c=>`<option value="${c}">${c}</option>`).join('');
  selDest.innerHTML = '<option value="">-- Todas --</option>' + todasCiudades.map(c=>`<option value="${c}">${c}</option>`).join('');
  document.getElementById('sal-fecha').value = today();
  if (TAQ_DATA.ciudad) {
    const match = [...selOrig.options].find(o => o.value.toLowerCase() === TAQ_DATA.ciudad.toLowerCase());
    if (match) {
      selOrig.value = match.value;
      // Quitar el origen del destino para evitar origen=destino
      const opcionesDest = todasCiudades.filter(c => c.toLowerCase() !== match.value.toLowerCase());
      selDest.innerHTML = '<option value="">-- Todas --</option>' + opcionesDest.map(c=>`<option value="${c}">${c}</option>`).join('');
    }
  }
  aplicarFiltrosSalidas();
}

function poblarFiltrosSalidas() {
  // no-op: población en cargarSalidas
}

function onSalOrigenChange() {
  const origenVal = document.getElementById('sal-origen').value.toLowerCase();
  const selDest   = document.getElementById('sal-destino');
  const prevDest  = selDest.value;
  const todasCiudades = [...new Set([
    ...salidasData.map(r=>r.origen_ciudad),
    ...salidasData.map(r=>r.destino_ciudad)
  ].filter(Boolean))].sort();
  const opciones = origenVal
    ? todasCiudades.filter(c => c.toLowerCase() !== origenVal)
    : todasCiudades;
  selDest.innerHTML = '<option value="">-- Todas --</option>' + opciones.map(c=>`<option value="${c}">${c}</option>`).join('');
  if (prevDest && prevDest.toLowerCase() !== origenVal) selDest.value = prevDest;
  aplicarFiltrosSalidas();
}

let salidasView = 'cards';

function setSalidasView(v) {
  salidasView = v;
  document.getElementById('sal-vbtn-cards').classList.toggle('active', v === 'cards');
  document.getElementById('sal-vbtn-tabla').classList.toggle('active', v === 'tabla');
  aplicarFiltrosSalidas();
}

function aplicarFiltrosSalidas() {
  const fechaSel  = document.getElementById('sal-fecha').value;
  const origenSel = document.getElementById('sal-origen').value.trim().toLowerCase();
  const destSel   = document.getElementById('sal-destino').value.trim().toLowerCase();
  const precision = document.getElementById('sal-precision').checked;
  let filtered    = salidasData;
  if (origenSel) filtered = filtered.filter(r=>(r.origen_ciudad||'').toLowerCase()===origenSel);
  if (destSel)   filtered = filtered.filter(r=>(r.destino_ciudad||'').toLowerCase()===destSel);
  if (fechaSel) {
    if (precision) {
      filtered = filtered.filter(r=>r.fecHoraSalida && r.fecHoraSalida.substring(0,10)===fechaSel);
    } else if (filtered.length) {
      const target    = new Date(fechaSel+'T00:00:00').getTime();
      const distancias = filtered.map(r=>r.fecHoraSalida ? Math.abs(new Date(r.fecHoraSalida).getTime()-target) : Infinity);
      const minDist   = Math.min(...distancias);
      filtered = filtered.filter((_,i)=>distancias[i]-minDist < 86400000);
    }
  }
  renderSalidaCards(filtered, precision ? null : fechaSel);
}

function limpiarFiltrosSalidas() {
  document.getElementById('sal-fecha').value   = today();
  document.getElementById('sal-origen').value  = '';
  document.getElementById('sal-destino').value = '';
  const cb = document.getElementById('sal-precision');
  if (cb) cb.checked = false;
  const tr = document.getElementById('sal-precision-track');
  const tx = document.getElementById('sal-precision-text');
  if (tr) tr.classList.remove('active');
  if (tx) tx.innerHTML = 'Precisión: <b>Cercana</b>';
  renderSalidaCards(salidasData);
}

function renderSalidaCards(trips, closestDate) {
  const cont = document.getElementById('salidas-container');
  const info = document.getElementById('sal-info');
  if (!trips.length) {
    cont.innerHTML = '<div class="empty-state"><div class="empty-icon">🚌</div><p>No hay salidas para los filtros seleccionados.</p></div>';
    if (info) info.textContent = '';
    return;
  }
  if (info) info.textContent = `Mostrando ${trips.length} salida(s)${closestDate?' — más cercano al '+closestDate:''}`;

  const origenes      = [...new Set(trips.map(r=>r.origen_ciudad).filter(Boolean))];
  const destinos      = [...new Set(trips.map(r=>r.destino_ciudad).filter(Boolean))];
  const soloUnOrigen  = origenes.length === 1;
  const soloUnDestino = destinos.length === 1;

  const headerHtml = soloUnOrigen && soloUnDestino
    ? `<div class="sal-origen-header">Salidas desde: <strong>${origenes[0]}</strong> &nbsp;→&nbsp; <strong>${destinos[0]}</strong></div>`
    : soloUnOrigen
      ? `<div class="sal-origen-header">Salidas desde: <strong>${origenes[0]}</strong></div>`
      : '';

  if (salidasView === 'tabla') {
    const mostrarOrigen  = !soloUnOrigen;
    const mostrarDestino = !soloUnDestino;
    const filas = trips.map(r => `
      <tr>
        <td>${r.numero}</td>
        <td><strong>${(r.fecHoraSalida||'').substring(11,16)||'—'}</strong></td>
        ${mostrarOrigen  ? `<td>${r.origen_ciudad||'—'}</td>` : ''}
        ${mostrarDestino ? `<td>${r.destino_ciudad||'—'}</td>` : ''}
        <td>${r.autobus_placas?'#'+r.autobus_num+' ('+r.autobus_placas+')':'—'}</td>
        <td>${r.conductor||'—'}</td>
        <td><span class="badge badge-info">${r.estado||'—'}</span></td>
        <td><button class="btn btn-naranja btn-sm" onclick='verDetalleSalida(${JSON.stringify(r)})'>Detalles</button></td>
      </tr>`).join('');
    cont.innerHTML = headerHtml + `
      <div class="tbl-wrap sal-tabla-wrap">
        <table class="sal-tabla">
          <thead>
            <tr>
              <th>#Viaje</th><th>Horario</th>
              ${mostrarOrigen  ? '<th>Origen</th>'  : ''}
              ${mostrarDestino ? '<th>Destino</th>' : ''}
              <th>Autobús</th><th>Conductor</th><th>Estado</th><th></th>
            </tr>
          </thead>
          <tbody>${filas}</tbody>
        </table>
      </div>`;
  } else {
    cont.innerHTML = headerHtml + `<div class="salidas-grid">${trips.map((r,idx)=>`
      <div class="salida-card-trip" style="animation-delay:${Math.min(idx*.04,.4)}s">
        <div class="sc-salida-title">Salida: ${fmt(r.fecHoraSalida)}</div>
        <div class="sc-viaje-num">Viaje #${r.numero}</div>
        ${soloUnOrigen && soloUnDestino
          ? `<div class="sc-horario-big">${(r.fecHoraSalida||'').substring(11,16)||'—'}</div>`
          : `<div class="sc-ruta">${soloUnOrigen?('→ '+(r.destino_ciudad||'—')):((r.origen_ciudad||'—')+' → '+(r.destino_ciudad||'—'))}</div>`
        }
        <div class="sc-meta">Autobús: ${r.autobus_placas?'#'+r.autobus_num+' ('+r.autobus_placas+')':'—'} &nbsp;|&nbsp; Conductor: ${r.conductor||'—'}</div>
        <div class="sc-footer">
          <span class="badge badge-info">${r.estado||'—'}</span>
          <button class="btn btn-naranja btn-sm" onclick='verDetalleSalida(${JSON.stringify(r)})'>Detalles</button>
        </div>
      </div>`).join('')}</div>`;
  }
}

function verDetalleSalida(r) {
  document.getElementById('modal-det-salida-body').innerHTML = `
    <div style="margin-bottom:18px;">
      <div style="font-size:18px;font-weight:900;color:var(--azul);margin-bottom:14px;">Viaje #${r.numero} — Ruta #${r.ruta??'—'}</div>
      <div class="det-grid2" style="margin-bottom:14px;">
        <div><div class="det-label">Fecha y hora de salida</div><div class="det-value">${fmt(r.fecHoraSalida)}</div></div>
        <div><div class="det-label">Fecha y hora de llegada est.</div><div class="det-value">${fmt(r.fecHoraEntrada)}</div></div>
      </div>
      <div class="det-grid2" style="margin-bottom:14px;">
        <div><div class="det-label">Ciudad de origen</div><div class="det-value">${r.origen_ciudad||'—'}</div></div>
        <div><div class="det-label">Terminal de salida</div><div class="det-value">${r.origen_terminal||'—'}</div></div>
        <div style="margin-top:10px;"><div class="det-label">Ciudad de destino</div><div class="det-value">${r.destino_ciudad||'—'}</div></div>
        <div style="margin-top:10px;"><div class="det-label">Terminal de llegada</div><div class="det-value">${r.destino_terminal||'—'}</div></div>
      </div>
      <div style="margin-bottom:14px;"><div class="det-label">Nombre completo del operador</div><div class="det-value">${r.conductor||'Sin asignar'}</div></div>
      <div class="det-grid2" style="margin-bottom:14px;">
        <div><div class="det-label">Número del autobús</div><div class="det-value">${r.autobus_num?'#'+r.autobus_num:'—'}</div></div>
        <div><div class="det-label">Matrícula</div><div class="det-value">${r.autobus_placas||'—'}</div></div>
      </div>
      ${r.precio_ruta!=null?`<div style="display:flex;align-items:center;gap:10px;background:rgba(17,129,195,.07);border:1px solid rgba(17,129,195,.18);border-radius:10px;padding:10px 16px;">
        <span style="font-size:20px;">🎟️</span>
        <div><div class="det-label" style="margin-bottom:2px;">Precio del viaje</div><div class="det-value" style="font-size:20px;font-weight:900;color:var(--azul);">$${parseFloat(r.precio_ruta).toFixed(2)} MXN</div></div>
      </div>`:''}
    </div>`;
  abrirModal('modal-det-salida');
}

// ════ MODAL AGREGAR VIAJE ══════════════

async function abrirModalViaje() {
  const d = await fetch('/api/viaje/opciones/').then(r=>r.json());
  rutasDuracion = {};
  d.rutas.forEach(r => { rutasDuracion[String(r.value)] = r.duracion || ''; });
  fillSelect('mv-ruta',      d.rutas,      'Seleccionar...');
  fillSelect('mv-autobus',   d.autobuses,  'Seleccionar...');
  fillSelect('mv-conductor', d.conductores,'Seleccionar...');
  fillSelect('mv-estado',    d.estados,    'Seleccionar...');
  const now = new Date();
  now.setMinutes(Math.ceil(now.getMinutes()/15)*15, 0, 0);
  document.getElementById('mv-salida').value          = toLocalDatetimeString(now);
  document.getElementById('mv-llegada').value         = '';
  document.getElementById('mv-llegada-display').value = 'Selecciona ruta para calcular…';
  calcularLlegadaAuto();
  abrirModal('modal-viaje');
}

function calcularLlegadaAuto() {
  const rutaId    = document.getElementById('mv-ruta').value;
  const salidaStr = document.getElementById('mv-salida').value;
  const displayEl = document.getElementById('mv-llegada-display');
  const hiddenEl  = document.getElementById('mv-llegada');
  if (!rutaId || !salidaStr) {
    displayEl.value = 'Selecciona ruta y hora de salida…';
    hiddenEl.value  = '';
    return;
  }
  const minutos = parseDuracionAMinutos(rutasDuracion[String(rutaId)] || '');
  if (!minutos) {
    displayEl.value = 'Duración de ruta no disponible';
    hiddenEl.value  = '';
    return;
  }
  const salida = parseDatetimeLocal(salidaStr);
  if (!salida || isNaN(salida.getTime())) {
    displayEl.value = 'Fecha de salida inválida';
    hiddenEl.value  = '';
    return;
  }
  const llegada = new Date(salida.getTime() + minutos * 60000);
  hiddenEl.value = toLocalDatetimeString(llegada);
  const opts = { weekday:'short', month:'short', day:'numeric', hour:'2-digit', minute:'2-digit' };
  displayEl.value = llegada.toLocaleDateString('es-MX', opts) +
    '  (+' + (minutos >= 60
      ? Math.floor(minutos/60) + 'h ' + (minutos % 60 ? minutos % 60 + 'min' : '')
      : minutos + 'min') + ')';
}

function parseDuracionAMinutos(dur) {
  if (!dur) return 0;
  dur = String(dur).trim().toLowerCase();
  if (/^\d+:\d+$/.test(dur)) {
    const [h, m] = dur.split(':').map(Number);
    return (h * 60) + (m || 0);
  }
  const hMatch  = dur.match(/(\d+)\s*h/);
  const mMatch  = dur.match(/(\d+)\s*m/);
  const horas   = hMatch ? parseInt(hMatch[1]) : 0;
  const minutos = mMatch ? parseInt(mMatch[1]) : 0;
  if (hMatch || mMatch) return (horas * 60) + minutos;
  const n = parseInt(dur);
  return isNaN(n) ? 0 : n;
}

async function submitViaje() {
  const llegada = document.getElementById('mv-llegada').value;
  const body = {
    salida:    document.getElementById('mv-salida').value,
    llegada,
    ruta:      document.getElementById('mv-ruta').value,
    autobus:   document.getElementById('mv-autobus').value,
    conductor: document.getElementById('mv-conductor').value,
    estado:    document.getElementById('mv-estado').value,
  };
  if (!body.salida||!body.llegada||!body.ruta||!body.autobus||!body.conductor||!body.estado) {
    toast('Completa todos los campos','err'); return;
  }
  const d = await fetch('/api/viaje/agregar/',{method:'POST',headers:csrfHeaders(),body:JSON.stringify(body)}).then(r=>r.json());
  d.ok ? (toast('Viaje agregado'), cerrarModal('modal-viaje'), cargarSalidas()) : toast('Error: '+d.error,'err');
}

// ════ HISTORIAL ════════════════════════

async function cargarHistorial() {
  document.getElementById('hist-cards-container').innerHTML =
    '<div style="text-align:center;padding:40px"><span class="spinner"></span></div>';
  try {
    const res = await fetch('/api/historial/panel/', { headers: { 'Accept': 'application/json' } });
    if (res.status === 401) {
      document.getElementById('hist-cards-container').innerHTML =
        '<div class="empty-state"><p>Sesión expirada. <a href="/login/">Vuelve a iniciar sesión</a>.</p></div>';
      return;
    }
    if (!res.ok) {
      document.getElementById('hist-cards-container').innerHTML =
        `<div class="empty-state"><p>Error del servidor (${res.status}). Intenta recargar la página.</p></div>`;
      return;
    }
    const d = await res.json();
    if (!d.rows) {
      document.getElementById('hist-cards-container').innerHTML =
        '<div class="empty-state"><p>Respuesta inesperada del servidor.</p></div>';
      return;
    }
    historialData = d.rows;
    historialBase = d.rows;

    const uniq = fn => [...new Set(d.rows.map(fn).filter(Boolean))].sort();
    const todasCiudades = [...new Set([
      ...d.rows.map(r => r.origen_ciudad),
      ...d.rows.map(r => r.destino_ciudad)
    ].filter(Boolean))].sort();

    // Estados disponibles en los datos
    const todosEstados = uniq(r => r.estado);
    // Estados "históricos" (viajes que ya ocurrieron)
    const estadosHistoricos = ['cancelado','finalizado','completado','terminado','en curso'];
    const estadosDefault = todosEstados.filter(e => estadosHistoricos.includes(e.toLowerCase()));

    document.getElementById('hist-estado').innerHTML =
      '<option value="__historico__">Todos (histórico)</option>' +
      '<option value="">Todos (general)</option>' +
      todosEstados.map(v => `<option value="${v}">${v}</option>`).join('');

    // Seleccionar "Todos (histórico)" por default
    document.getElementById('hist-estado').value = '__historico__';

    const selOrig = document.getElementById('hist-origen');
    selOrig.innerHTML = '<option value="">-- Todas --</option>' +
      todasCiudades.map(c => `<option value="${c}">${c}</option>`).join('');

    const selDest = document.getElementById('hist-destino');
    selDest.innerHTML = '<option value="">-- Todas --</option>' +
      todasCiudades.map(c => `<option value="${c}">${c}</option>`).join('');

    if (TAQ_DATA.ciudad) {
      const match = [...selOrig.options].find(o => o.value.toLowerCase() === TAQ_DATA.ciudad.toLowerCase());
      if (match) {
        selOrig.value = match.value;
        _actualizarDestinosHistorial(match.value, '');
      }
    }

    initPrecisionToggle('hist-precision','hist-precision-track','hist-precision-text','hist-precision-label');
    document.getElementById('hist-fecha').value = '';
    filtrarHistorial();
  } catch(e) {
    document.getElementById('hist-cards-container').innerHTML =
      `<div class="empty-state"><p>No se pudo cargar el historial: ${e.message}</p></div>`;
  }
}

function _actualizarDestinosHistorial(origenVal, prevDest) {
  const todasCiudades = [...new Set([
    ...historialData.map(r => r.origen_ciudad),
    ...historialData.map(r => r.destino_ciudad)
  ].filter(Boolean))].sort();
  const selDest = document.getElementById('hist-destino');
  const opciones = origenVal
    ? todasCiudades.filter(c => c.toLowerCase() !== origenVal.toLowerCase())
    : todasCiudades;
  selDest.innerHTML = '<option value="">-- Todas --</option>' +
    opciones.map(c => `<option value="${c}">${c}</option>`).join('');
  if (prevDest && prevDest.toLowerCase() !== origenVal.toLowerCase()) {
    selDest.value = prevDest;
  }
}

function onHistOrigenChange() {
  const origenVal = document.getElementById('hist-origen').value;
  const prevDest  = document.getElementById('hist-destino').value;
  _actualizarDestinosHistorial(origenVal, prevDest);
  filtrarHistorial();
}

function filtrarHistorial() {
  const q  = document.getElementById('hist-search').value.toLowerCase();
  const es = document.getElementById('hist-estado').value;
  const or = document.getElementById('hist-origen').value;
  const de = document.getElementById('hist-destino').value;

  // Estados que se consideran "históricos" (ya ocurrieron o fueron cancelados)
  const ESTADOS_HISTORICOS = ['cancelado','finalizado','completado','terminado','en curso'];

  historialBase = historialData.filter(r => {
    const txt = [r.origen_ciudad,r.destino_ciudad,r.conductor,r.autobus_placas,String(r.numero),String(r.autobus_num)].join(' ').toLowerCase();
    const pasaTexto  = txt.includes(q);
    const pasaOrigen = !or || r.origen_ciudad === or;
    const pasaDest   = !de || r.destino_ciudad === de;
    let pasaEstado;
    if (es === '__historico__') {
      pasaEstado = ESTADOS_HISTORICOS.includes((r.estado||'').toLowerCase());
    } else if (es === '') {
      pasaEstado = true; // todos general
    } else {
      pasaEstado = r.estado === es;
    }
    return pasaTexto && pasaOrigen && pasaDest && pasaEstado;
  });
  const fecha = document.getElementById('hist-fecha').value;
  if (fecha) { _aplicarFechaHistorial(historialBase, fecha); }
  else { historialFiltered = historialBase; _renderHistInfoAndCards(historialFiltered); }
}

function aplicarFiltrosFechaHistorial() {
  const fecha = document.getElementById('hist-fecha').value;
  if (!fecha) { historialFiltered = historialBase; _renderHistInfoAndCards(historialFiltered, null); return; }
  _aplicarFechaHistorial(historialBase, fecha);
}

function _aplicarFechaHistorial(subset, fecha) {
  const precision = document.getElementById('hist-precision').checked;
  if (precision) {
    historialFiltered = subset.filter(r=>r.fecHoraSalida && r.fecHoraSalida.substring(0,10)===fecha);
    _renderHistInfoAndCards(historialFiltered, null);
  } else {
    if (!subset.length) { _renderHistInfoAndCards([], null); return; }
    const target  = new Date(fecha+'T00:00:00').getTime();
    const dists   = subset.map(r=>r.fecHoraSalida ? Math.abs(new Date(r.fecHoraSalida).getTime()-target) : Infinity);
    const minDist = Math.min(...dists);
    historialFiltered = subset.filter((_,i)=>dists[i]-minDist < 86400000);
    const fechaCercana = historialFiltered.length ? historialFiltered[0].fecHoraSalida.substring(0,10) : null;
    _renderHistInfoAndCards(historialFiltered, fechaCercana);
  }
}

function _renderHistInfoAndCards(rows, fechaHint) {
  const hint = fechaHint ? ` — más cercano al ${document.getElementById('hist-fecha').value} (${fechaHint})` : '';
  document.getElementById('hist-info').textContent = `Mostrando ${rows.length} de ${historialData.length} viajes${hint}`;
  if (histView === 'tabla') renderHistorialTabla(rows);
  else renderHistorialCards(rows);
}

function limpiarFiltrosHistorial() {
  ['hist-search','hist-fecha'].forEach(id=>{
    document.getElementById(id).value = '';
  });
  document.getElementById('hist-estado').value = '__historico__';
  const cb    = document.getElementById('hist-precision');
  const track = document.getElementById('hist-precision-track');
  const txt   = document.getElementById('hist-precision-text');
  if (cb)    cb.checked = false;
  if (track) track.classList.remove('active');
  if (txt)   txt.innerHTML = 'Precisión: <b>Cercana</b>';

  const selOrig = document.getElementById('hist-origen');
  selOrig.value = '';
  if (TAQ_DATA.ciudad) {
    const match = [...selOrig.options].find(o => o.value.toLowerCase() === TAQ_DATA.ciudad.toLowerCase());
    if (match) selOrig.value = match.value;
  }
  _actualizarDestinosHistorial(selOrig.value, '');

  historialBase = historialData;
  historialFiltered = historialData;
  filtrarHistorial();
}

function initPrecisionToggle(cbId, trackId, txtId, labelId) {
  const cb    = document.getElementById(cbId);
  const track = document.getElementById(trackId);
  const txt   = document.getElementById(txtId);
  const label = document.getElementById(labelId);
  if (!cb || !track) return;
  const sync = () => {
    const on = cb.checked;
    track.classList.toggle('active', on);
    if (txt) txt.innerHTML = on ? 'Precisión: <b>Exacta</b>' : 'Precisión: <b>Cercana</b>';
  };
  label.addEventListener('click', () => { cb.checked = !cb.checked; sync(); });
  sync();
}

let histView = 'cards';

function setHistView(v) {
  histView = v;
  document.getElementById('hist-vbtn-cards').classList.toggle('active', v === 'cards');
  document.getElementById('hist-vbtn-tabla').classList.toggle('active', v === 'tabla');
  if (v === 'tabla') {
    document.getElementById('hist-cards-container').style.display = 'none';
    document.getElementById('hist-tabla-wrap').style.display = '';
    renderHistorialTabla(historialFiltered);
  } else {
    document.getElementById('hist-tabla-wrap').style.display = 'none';
    document.getElementById('hist-cards-container').style.display = '';
    renderHistorialCards(historialFiltered);
  }
}

function _estadoBadgeHist(estado) {
  const e = (estado||'').toLowerCase();
  if (e.includes('finaliz')) return `<span class="ht-badge ht-badge-fin">${estado}</span>`;
  if (e.includes('ruta'))    return `<span class="ht-badge ht-badge-ruta">${estado}</span>`;
  if (e.includes('dispon'))  return `<span class="ht-badge ht-badge-disp">${estado}</span>`;
  if (e.includes('cancel'))  return `<span class="ht-badge ht-badge-can">${estado}</span>`;
  return `<span class="ht-badge ht-badge-fin">${estado||'—'}</span>`;
}

function renderHistorialTabla(rows) {
  document.getElementById('hist-cards-container').style.display = 'none';
  document.getElementById('hist-tabla-wrap').style.display = '';
  const tbl = document.getElementById('hist-tabla');
  const cols = ['Viaje','Ruta','Origen','Destino','Salida','Llegada','Estado','Operador','Autobús','Asientos','Pasajeros','Acciones'];
  tbl.querySelector('thead').innerHTML =
    `<tr>${cols.map(c=>`<th>${c}</th>`).join('')}</tr>`;
  if (!rows.length) {
    tbl.querySelector('tbody').innerHTML =
      `<tr><td colspan="${cols.length}" style="text-align:center;color:var(--muted);padding:32px">Sin viajes para los filtros seleccionados.</td></tr>`;
    return;
  }
  tbl.querySelector('tbody').innerHTML = rows.map(r => `<tr>
    <td style="font-weight:700;color:var(--azul)">#${r.numero}</td>
    <td style="color:var(--muted)">Ruta #${r.ruta??'—'}</td>
    <td>${r.origen_terminal??r.origen_ciudad??'—'}</td>
    <td>${r.destino_terminal??r.destino_ciudad??'—'}</td>
    <td style="white-space:nowrap">${fmt(r.fecHoraSalida)}</td>
    <td style="white-space:nowrap">${fmt(r.fecHoraEntrada)}</td>
    <td>${_estadoBadgeHist(r.estado)}</td>
    <td>${r.conductor??'—'}</td>
    <td style="white-space:nowrap">${r.autobus_num?'#'+r.autobus_num:'—'}${r.autobus_placas?' · '+r.autobus_placas:''}</td>
    <td style="text-align:center">${r.asientos_total??'—'}</td>
    <td style="text-align:center;font-weight:700">${r.pasajeros_count??'—'}</td>
    <td>
      <div class="ht-btn-wrap">
        <button class="btn btn-naranja" onclick="verAutobus(${r.numero},${r.autobus_num??'null'})">Autobús</button>
        <button class="btn btn-primary"  onclick="verPasajeros(${r.numero})">Pasajeros</button>
      </div>
    </td>
  </tr>`).join('');
}

function exportarHistorialCSV() {
  if (!historialFiltered.length) { toast('No hay viajes para exportar', 'err'); return; }
  const esc = v => `"${(v??'').toString().replace(/"/g,'""')}"`;
  const header = ['Viaje','Ruta','Origen terminal','Ciudad origen','Destino terminal','Ciudad destino',
                  'Salida','Llegada','Estado','Operador','Autobús #','Matrícula','Asientos','Pasajeros'];
  const rows = historialFiltered.map(r => [
    r.numero, r.ruta??'',
    r.origen_terminal??'', r.origen_ciudad??'',
    r.destino_terminal??'', r.destino_ciudad??'',
    r.fecHoraSalida??'', r.fecHoraEntrada??'',
    r.estado??'', r.conductor??'',
    r.autobus_num??'', r.autobus_placas??'',
    r.asientos_total??'', r.pasajeros_count??''
  ].map(esc).join(','));
  const csv = [header.map(esc).join(','), ...rows].join('\r\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob(['\uFEFF' + csv], {type:'text/csv;charset=utf-8'}));
  a.download = `historial_viajes_${new Date().toISOString().slice(0,10)}.csv`;
  a.click();
  toast(`CSV exportado — ${historialFiltered.length} viaje(s)`);
}

function renderHistorialCards(rows) {
  document.getElementById('hist-tabla-wrap').style.display = 'none';
  document.getElementById('hist-cards-container').style.display = '';
  const container = document.getElementById('hist-cards-container');
  if (!rows.length) {
    container.innerHTML = `<div class="empty-state"><div class="empty-icon">🔍</div><p>No se encontraron viajes.</p></div>`;
    return;
  }
  container.innerHTML = rows.map((r,idx)=>`
    <div class="viaje-card" style="animation-delay:${Math.min(idx*.04,.4)}s">
      <div class="viaje-card-inner">
        <div class="viaje-card-stripe"></div>
        <div class="viaje-card-body">
          <div class="viaje-card-header">
            <span class="viaje-card-num">Viaje #${r.numero}</span>
            <span style="color:var(--muted)">—</span>
            <span class="viaje-card-ruta">Ruta #${r.ruta??'—'}</span>
            <span class="badge badge-info" style="margin-left:auto">${r.estado??'—'}</span>
          </div>
          <div class="viaje-card-route">${r.origen_terminal??r.origen_ciudad??'—'}<span class="arrow">→</span>${r.destino_terminal??r.destino_ciudad??'—'}</div>
          <div class="viaje-card-meta">
            <span><b>Salida:</b> ${fmt(r.fecHoraSalida)}</span><span>•</span>
            <span><b>Llegada:</b> ${fmt(r.fecHoraEntrada)}</span>
          </div>
          <div class="viaje-card-row2">
            <span><b>Operador:</b> ${r.conductor??'—'}</span><span>•</span>
            <span><b>Autobús:</b> ${r.autobus_num?'#'+r.autobus_num:'—'}${r.autobus_placas?' · '+r.autobus_placas:''}</span><span>•</span>
            <span><b>Asientos:</b> ${r.asientos_total??'—'}</span><span>•</span>
            <span><b>Pasajeros:</b> ${r.pasajeros_count??'—'}</span>
          </div>
        </div>
        <div class="viaje-card-actions">
          <button class="btn btn-naranja" onclick="verAutobus(${r.numero},${r.autobus_num??'null'})">Autobús</button>
          <button class="btn btn-primary"  onclick="verPasajeros(${r.numero})">Pasajeros</button>
        </div>
      </div>
    </div>`).join('');
}

// ════ MODALES HISTORIAL ════════════════

async function verAutobus(viajeId, busNum) {
  if (!busNum) { toast('Sin autobús asignado','err'); return; }
  document.getElementById('modal-autobus-title').textContent = `Información del Autobús — Viaje ${viajeId}`;
  document.getElementById('modal-autobus-body').innerHTML = '<div style="text-align:center;padding:20px"><span class="spinner"></span></div>';
  abrirModal('modal-autobus');
  try {
    const d = await fetch(`/api/autobus/detalle/${busNum}/`).then(r=>r.json());
    if (d.error) { document.getElementById('modal-autobus-body').innerHTML=`<p style="color:var(--danger)">${d.error}</p>`; return; }
    const tiposHtml = d.tipos_asiento?.length
      ? `<ul class="bus-tipo-list">${d.tipos_asiento.map(t=>`<li>${t.descripcion} (${t.codigo}): ${t.cantidad}</li>`).join('')}</ul>`
      : '—';
    document.getElementById('modal-autobus-body').innerHTML = `
      <div class="bus-info-row"><span class="bus-info-label">Número:</span><span class="bus-info-value">${d.numero}</span></div>
      <div class="bus-info-row"><span class="bus-info-label">Matrícula:</span><span class="bus-info-value">${d.placas}</span></div>
      <div class="bus-info-row"><span class="bus-info-label">Marca:</span><span class="bus-info-value">${d.marca}</span></div>
      <div class="bus-info-row"><span class="bus-info-label">Modelo:</span><span class="bus-info-value">${d.modelo}</span></div>
      <div class="bus-info-row"><span class="bus-info-label">Año:</span><span class="bus-info-value">${d.anio}</span></div>
      <div class="bus-info-row"><span class="bus-info-label">Asientos:</span><span class="bus-info-value">${d.num_asientos}</span></div>
      <div class="bus-info-row"><span class="bus-info-label">Por tipo:</span><span class="bus-info-value">${tiposHtml}</span></div>`;
  } catch(e) {
    document.getElementById('modal-autobus-body').innerHTML = '<p style="color:var(--danger)">Error al cargar.</p>';
  }
}

async function verPasajeros(viajeId) {
  document.getElementById('modal-pasajeros-title').textContent = `Pasajeros del viaje ${viajeId}`;
  document.getElementById('modal-pasajeros-header').innerHTML  = '';
  document.getElementById('modal-pasajeros-tbody').innerHTML   =
    '<tr><td colspan="5" style="text-align:center;padding:20px"><span class="spinner"></span></td></tr>';
  abrirModal('modal-pasajeros');
  try {
    const d = await fetch(`/api/viaje/pasajeros/${viajeId}/`).then(r=>r.json());
    if (d.error) {
      document.getElementById('modal-pasajeros-tbody').innerHTML =
        `<tr><td colspan="5" style="text-align:center;color:var(--danger);padding:20px">${d.error}</td></tr>`;
      return;
    }
    pasajerosActuales  = d.pasajeros||[];
    pasajerosViajeInfo = {...d.viaje||{}, viaje_id:viajeId};
    const v = d.viaje||{};
    document.getElementById('modal-pasajeros-header').innerHTML = `
      <span class="pasajeros-header-item">Viaje: <b>${viajeId}</b></span>
      <span class="pasajeros-header-item">Origen: <b>${v.origen??'—'}</b></span>
      <span class="pasajeros-header-item">Destino: <b>${v.destino??'—'}</b></span>
      <span class="pasajeros-header-item">Salida: <b>${v.salida?fmt(v.salida):'—'}</b></span>
      <span class="pasajeros-header-item">Autobús: <b>${v.autobus??'—'}</b></span>`;
    if (!pasajerosActuales.length) {
      document.getElementById('modal-pasajeros-tbody').innerHTML =
        '<tr><td colspan="5" style="text-align:center;color:var(--muted);padding:24px">Sin pasajeros</td></tr>';
      return;
    }
    document.getElementById('modal-pasajeros-tbody').innerHTML =
      pasajerosActuales.map((p,i)=>`<tr>
        <td>${i+1}</td><td>${p.nombre_completo??'—'}</td><td>${p.edad??'—'}</td>
        <td>${p.numero_boleto??'—'}</td><td>${p.numero_asiento??'—'}</td>
      </tr>`).join('');
  } catch(e) {
    document.getElementById('modal-pasajeros-tbody').innerHTML =
      '<tr><td colspan="5" style="text-align:center;color:var(--danger);padding:20px">Error.</td></tr>';
  }
}

function exportarPasajerosCSV() {
  if (!pasajerosActuales.length) { toast('Sin pasajeros','err'); return; }
  const v   = pasajerosViajeInfo;
  const meta = `# Viaje: ${v.viaje_id??'?'} | Origen: ${v.origen??'?'} | Destino: ${v.destino??'?'}`;
  const csv  = [meta,'Nombre completo,Edad,Número boleto,Número asiento',
    ...pasajerosActuales.map(p=>`"${p.nombre_completo??''}","${p.edad??''}","${p.numero_boleto??''}","${p.numero_asiento??''}"`)
  ].join('\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv],{type:'text/csv;charset=utf-8'}));
  a.download = `pasajeros_viaje_${v.viaje_id??'x'}.csv`;
  a.click();
  toast('CSV exportado');
}

// ════ GESTIÓN CRUD ══════════════════════

const COLS_IMAGEN = new Set(['foto']);
const COLS_OCULTAS_CARDS = new Set(['serieVIN', 'serievin', 'firebase_uid', 'clave', 'contrasena']);

// Aliases de columnas: se muestran en headers/labels con nombre amigable sin alterar la BD
const COL_ALIAS = {
  'ano': 'año',
  'contrasena': 'contraseña',
  'numasientos': 'num. asientos',
  'fechacontrato': 'fecha contrato',
  'fechanacimiento': 'fecha nacimiento',
  'fechapago': 'fecha pago',
  'fechoemision': 'fecha emisión',
  'tipopasajero': 'tipo pasajero',
  'firebase_uid': 'firebase uid',
};
function colLabel(c) { return COL_ALIAS[c.toLowerCase()] ?? c; }

function setGestionView(view) {
  gestionView = view;
  document.getElementById('gvt-tabla').classList.toggle('active', view === 'tabla');
  document.getElementById('gvt-cards').classList.toggle('active', view === 'cards');
  document.getElementById('gestion-tabla-wrap').style.display = view === 'tabla' ? '' : 'none';
  document.getElementById('gestion-cards-wrap').style.display = view === 'cards' ? '' : 'none';
  if (gestionLastData) {
    if (view === 'tabla') renderGestionTabla(gestionLastData);
    else                  renderGestionCards(gestionLastData);
  }
}

function celdaGestion(col, val) {
  if (COLS_IMAGEN.has(col) && val && val !== '—') {
    const url = val.startsWith('http') ? val : `/media/${val}`;
    return `<td><img src="${url}" alt="foto"
      style="width:44px;height:44px;object-fit:cover;border-radius:50%;border:2px solid var(--border);cursor:pointer;vertical-align:middle;"
      onerror="this.style.display='none'"
      onclick="verFotoGrande('${url}')"></td>`;
  }
  return `<td>${val??'—'}</td>`;
}

const TABLAS_CON_LEGIBLE = new Set([
  'modelo', 'ruta', 'viaje', 'asiento', 'viaje_asiento',
  'taquillero', 'ticket', 'pago'
]);

function onDbToggleChange() {
  const chk = document.getElementById('db-toggle-chk');
  if (chk.checked && !TABLAS_CON_LEGIBLE.has(tablaActual.nombre)) {
    chk.checked = false;
    toast('No es necesario este modo aquí', 'err');
    return;
  }
  gestionModo = chk.checked ? 'legible' : 'db';
  document.getElementById('db-toggle-lbl-db').classList.toggle('active', !chk.checked);
  document.getElementById('db-toggle-lbl-leg').classList.toggle('active', chk.checked);
  recargarGestion();
}

function _syncDbToggleUI() {
  const chk = document.getElementById('db-toggle-chk');
  chk.checked = (gestionModo === 'legible');
  document.getElementById('db-toggle-lbl-db').classList.toggle('active', gestionModo !== 'legible');
  document.getElementById('db-toggle-lbl-leg').classList.toggle('active', gestionModo === 'legible');
  document.getElementById('db-toggle-wrap').style.display = 'flex';
}

async function recargarGestion(limit) {
  const tabla = tablaActual.nombre;
  if (!tabla) return;
  document.getElementById('gestion-search-wrap').style.display = '';
  _syncDbToggleUI();
  const inp = document.getElementById('gestion-search');
  inp.value = '';
  document.getElementById('gestion-search-clear').style.display = 'none';
  document.getElementById('gestion-tbody').innerHTML = '<tr><td colspan="20"><span class="spinner"></span></td></tr>';
  document.getElementById('gestion-cards-wrap').innerHTML = '<div style="text-align:center;padding:40px"><span class="spinner"></span></div>';
  document.getElementById('gestion-ver-todos-wrap').style.display = 'none';

  // FAB modo asistido: solo visible desde Salidas programadas, nunca en Gestión
  const fabAsistido = document.getElementById('fab-modo-asistido');
  if (fabAsistido) fabAsistido.style.display = 'none';

  const lim = limit || 500;
  const url = `/api/crud/${tabla}/leer/?modo=${gestionModo}&limit=${lim}`;
  const d = await fetch(url).then(r=>r.json());
  if (d.error) { toast(d.error,'err'); return; }

  gestionLastData = d;

  const badge = `<span class="modo-badge ${gestionModo}">${gestionModo === 'legible' ? '🔤 Legible' : '🗄 DB'}</span>`;
  const totalReal = d.total_real ?? d.rows.length;
  const hayMas    = totalReal > d.rows.length;
  document.getElementById('gestion-info').innerHTML =
    `${d.rows.length} de ${totalReal} registro(s)${badge}`;

  // Botón "Ver todos" si hay registros ocultos por el límite
  if (hayMas) {
    document.getElementById('ver-todos-count').textContent = totalReal;
    document.getElementById('gestion-ver-todos-wrap').style.display = '';
  }

  if (gestionView === 'tabla') renderGestionTabla(d);
  else                         renderGestionCards(d);
}

function verTodosRegistros() {
  recargarGestion(5000);
}

function abrirModoAsistido() {
  // Abre el modal de viaje asistido (el mismo de Salidas programadas)
  abrirModalViaje();
}


function _infoBadge() {
  return `<span class="modo-badge ${gestionModo}">${gestionModo === 'legible' ? '🔤 Legible' : '🗄 DB'}</span>`;
}

function filtrarGestion() {
  const q = document.getElementById('gestion-search').value.trim().toLowerCase();
  document.getElementById('gestion-search-clear').style.display = q ? '' : 'none';
  if (!gestionLastData) return;
  if (!q) {
    if (gestionView === 'tabla') renderGestionTabla(gestionLastData);
    else                         renderGestionCards(gestionLastData);
    document.getElementById('gestion-info').innerHTML = `${gestionLastData.rows.length} registro(s)${_infoBadge()}`;
    return;
  }
  const filtradas = gestionLastData.rows.filter(row =>
    Object.values(row).some(v => v !== null && String(v).toLowerCase().includes(q))
  );
  const datFiltrada = { cols: gestionLastData.cols, rows: filtradas };
  const total = gestionLastData.rows.length;
  document.getElementById('gestion-info').innerHTML =
    `${filtradas.length} resultado(s) de ${total} registro(s)${_infoBadge()}`;
  if (gestionView === 'tabla') renderGestionTabla(datFiltrada, q);
  else                         renderGestionCards(datFiltrada, q);
}

function limpiarBusqueda() {
  document.getElementById('gestion-search').value = '';
  document.getElementById('gestion-search-clear').style.display = 'none';
  filtrarGestion();
}

function highlightMatch(text, q) {
  if (!q || !text) return text ?? '—';
  const str = String(text);
  if (!q) return str;
  const idx = str.toLowerCase().indexOf(q.toLowerCase());
  if (idx === -1) return str;
  return (
    str.substring(0, idx) +
    `<span class="search-hl">${str.substring(idx, idx + q.length)}</span>` +
    str.substring(idx + q.length)
  );
}

function renderGestionTabla(d, q = '') {
  const tabla = tablaActual.nombre;
  document.getElementById('gestion-thead').innerHTML =
    `<tr>${d.cols.map(c=>`<th>${colLabel(c)}</th>`).join('')}<th>Acciones</th></tr>`;
  if (!d.rows.length) {
    document.getElementById('gestion-tbody').innerHTML =
      '<tr><td colspan="20" style="text-align:center;color:var(--muted)">Sin registros</td></tr>';
    return;
  }
  const pk = d.cols[0];
  document.getElementById('gestion-tbody').innerHTML = d.rows.map(row=>`
    <tr>
      ${d.cols.map(c=>{
        if (COLS_IMAGEN.has(c) && row[c] && row[c] !== '—') {
          const url = String(row[c]).startsWith('http') ? row[c] : `/media/${row[c]}`;
          return `<td><img src="${url}" alt="foto"
            style="width:44px;height:44px;object-fit:cover;border-radius:50%;border:2px solid var(--border);cursor:pointer;vertical-align:middle;"
            onerror="this.style.display='none'"
            onclick="verFotoGrande('${url}')"></td>`;
        }
        // Columnas de contrasena: mostrar mascara en tabla (solo taquillero para 'clave')
        const esColPass = c === 'contrasena' || (c === 'clave' && tabla === 'taquillero');
        if (esColPass && row[c]) {
          return `<td style="color:var(--muted);letter-spacing:2px">\u2022\u2022\u2022\u2022\u2022\u2022</td>`;
        }
        return `<td>${highlightMatch(row[c], q)}</td>`;
      }).join('')}
      <td style="white-space:nowrap"><div style="display:flex;gap:4px;flex-wrap:wrap">
        <button class="btn btn-gray btn-sm"    onclick='verDetalle(${JSON.stringify(d.cols)},${JSON.stringify(row)})'>Ver</button>
        <button class="btn btn-naranja btn-sm" onclick='abrirEditar("${tabla}","${pk}","${row[pk]}")'>Editar</button>
        <button class="btn btn-danger btn-sm"  onclick='eliminarReg("${tabla}","${pk}","${row[pk]}")'>Eliminar</button>
      </div></td>
    </tr>`).join('');
}

function renderGestionCards(d, q = '') {
  const tabla = tablaActual.nombre;
  const wrap  = document.getElementById('gestion-cards-wrap');
  if (!d.rows.length) {
    wrap.innerHTML = '<div class="empty-state"><div class="empty-icon">📭</div><p>Sin registros</p></div>';
    return;
  }
  const pk = d.cols[0];
  wrap.innerHTML = `<div class="gestion-cards-grid">${d.rows.map((row, idx) => {
    const pkVal   = row[pk];
    const pkLabel = `${pk.charAt(0).toUpperCase() + pk.slice(1)} #${pkVal}`;
    const fotoCol = d.cols.find(c => COLS_IMAGEN.has(c));
    const fotoVal = fotoCol ? row[fotoCol] : null;
    const fotoHtml = fotoVal && fotoVal !== '—'
      ? `<img class="gc-card-foto" src="${fotoVal.startsWith('http') ? fotoVal : '/media/'+fotoVal}"
           onerror="this.style.display='none'" onclick="verFotoGrande('${fotoVal.startsWith('http') ? fotoVal : '/media/'+fotoVal}')">`
      : '';
    const camposCols = d.cols.filter(c =>
      c !== pk &&
      !COLS_IMAGEN.has(c) &&
      !COLS_OCULTAS_CARDS.has(c)
    );
    const camposHtml = camposCols.map(c => `
      <div class="gc-field">
        <span class="gc-field-key">${colLabel(c)}</span>
        <span class="gc-field-val">${highlightMatch(row[c], q)}</span>
      </div>`).join('');
    return `
      <div class="gc-card" style="animation-delay:${Math.min(idx*.03,.3)}s">
        <div class="gc-card-header">
          <span class="gc-card-id">${pkLabel}</span>
          ${fotoHtml}
        </div>
        <div class="gc-card-fields">${camposHtml}</div>
        <div class="gc-card-actions">
          <button class="btn btn-gray btn-sm"    onclick='verDetalle(${JSON.stringify(d.cols)},${JSON.stringify(row)})'>Ver</button>
          <button class="btn btn-naranja btn-sm" onclick='abrirEditar("${tabla}","${pk}","${pkVal}")'>Editar</button>
          <button class="btn btn-danger btn-sm"  onclick='eliminarReg("${tabla}","${pk}","${pkVal}")'>Eliminar</button>
        </div>
      </div>`;
  }).join('')}</div>`;
}

function verFotoGrande(url) {
  const overlay = document.createElement('div');
  overlay.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.75);z-index:9999;display:flex;align-items:center;justify-content:center;cursor:zoom-out;';
  overlay.innerHTML = `<img src="${url}" style="max-width:90vw;max-height:85vh;border-radius:12px;box-shadow:0 8px 48px rgba(0,0,0,.6);">`;
  overlay.onclick   = () => overlay.remove();
  document.body.appendChild(overlay);
}

async function abrirInsertar() {
  const tabla = tablaActual.nombre;
  if (!tabla) { toast('Selecciona una tabla','err'); return; }
  try {
    const [esq, pkInfo] = await Promise.all([
      fetch(`/api/crud/${tabla}/esquema/`).then(r=>r.json()),
      fetch(`/api/crud/${tabla}/next_pk/`).then(r=>r.json()),
    ]);

    tablaActual.esquema = esq;
    tablaActual.modo    = 'insertar';
    tablaActual.nextId  = pkInfo.ok ? pkInfo.next_id : 1;
    tablaActual.pkCol   = pkInfo.ok ? pkInfo.pk_col  : null;

    document.getElementById('crud-modal-title').textContent = `Insertar en ${tabla}`;
    document.getElementById('crud-submit-btn').textContent  = 'Insertar';

    // Mostrar/ocultar botón modo asistido dentro del modal
    const btnAs = document.getElementById('crud-btn-asistido');
    if (btnAs) btnAs.style.display = tabla === 'viaje' ? '' : 'none';

    renderCrudForm(esq, null);
    abrirModal('modal-crud');
  } catch (e) {
    toast('Error al preparar formulario','err');
    console.error(e);
  }
}

async function abrirEditar(tabla, pk, pkv) {
  const esq   = await fetch(`/api/crud/${tabla}/esquema/`).then(r=>r.json());
  const datos = await fetch(`/api/crud/${tabla}/leer/`).then(r=>r.json());
  const row   = datos.rows.find(r=>String(r[pk])===String(pkv));
  tablaActual.esquema  = esq;
  tablaActual.modo     = 'editar';
  tablaActual.pkName   = pk;
  tablaActual.pkValue  = pkv;
  document.getElementById('crud-modal-title').textContent = `Editar — ${tabla}`;
  document.getElementById('crud-submit-btn').textContent  = 'Guardar';
  renderCrudForm(esq, row);
  abrirModal('modal-crud');
}

// Campos de cuenta_pasajero que viven en Firebase — advertencia al editar
const CAMPOS_FIREBASE = {
  clave:        { nivel: 'peligro', msg: 'La contraseña se gestiona en Firebase Authentication. Modificarla aquí <strong>no actualiza Firebase</strong> y puede impedir que el usuario inicie sesión en la app.' },
  firebase_uid: { nivel: 'peligro', msg: 'Este UID es generado por Firebase. Cambiarlo manualmente <strong>romperá el acceso</strong> del usuario en la app móvil.' },
  proveedor:    { nivel: 'info',    msg: 'Este campo indica el método de login (local / google). Cámbialo solo si sabes lo que haces; un valor incorrecto puede bloquear el acceso desde la app.' },
  correo:       { nivel: 'info',    msg: 'Cambiar el correo aquí no lo actualiza en Firebase. El usuario seguirá entrando con el correo anterior desde la app hasta que se sincronice.' },
};

function renderCrudForm(esq, vals) {
  const c     = document.getElementById('crud-form-fields');
  const tabla = tablaActual.nombre;
  c.innerHTML = '';

  // [CAM-1] Banner general para cuenta_pasajero
  if (tabla === 'cuenta_pasajero') {
    const banner = document.createElement('div');
    banner.style.cssText = `
      background:#fff8e1;border:1.5px solid #f59e0b;border-radius:8px;
      padding:10px 14px;margin-bottom:14px;font-size:13px;color:#92400e;
      display:flex;gap:10px;align-items:flex-start;line-height:1.5;`;
    banner.innerHTML = `
      <span style="font-size:18px;flex-shrink:0">⚠️</span>
      <div>
        <strong>Tabla sincronizada con Firebase</strong><br>
        Algunos campos de esta tabla están controlados por Firebase Authentication
        (la autenticación de la app móvil). Modifica solo los campos que no afecten
        el inicio de sesión, como la foto. Los campos críticos muestran una advertencia individual.
      </div>`;
    c.appendChild(banner);
  }

  esq.columnas.forEach(col => {
    const name = col.Field;
    let val = vals ? (vals[name] ?? '') : '';
    const isPK = col.Key === 'PRI';
    if (!vals && isPK && tablaActual.nextId) {
      val = tablaActual.nextId;
    }
    const isEditing = tablaActual.modo === 'editar';
    const div = document.createElement('div');
    div.className = 'form-field';
    if (esq.fk_map[name]) {
      const opts = esq.opciones[name] || [];
      div.innerHTML = `
        <label>${colLabel(name)}</label>
        <select data-field="${name}" ${isPK && isEditing ? 'disabled' : ''}>
          <option value="">— seleccionar —</option>
          ${opts.map(o => `
            <option value="${o.value}" ${String(o.value) === String(val) ? 'selected' : ''}>
              ${o.label}
            </option>`).join('')}
        </select>
      `;
    } else {
      const readOnly = isPK && isEditing;
      const colType  = col.Type.toLowerCase();
      let inputType  = 'text';
      let extraAttrs = '';
      let placeholder = '';

      // Campo contrasena: type=password, nunca mostrar hash, placeholder descriptivo
      if (name === 'contrasena' || name === 'clave') {
        div.innerHTML = `
          <label>${colLabel(name)} ${isEditing ? '<span style="font-size:11px;color:var(--muted)">(dejar vacío para no cambiar)</span>' : ''}</label>
          <input data-field="${name}" type="password" value=""
            placeholder="••••••  ${isEditing ? 'Nueva contraseña (opcional)' : 'Contraseña'}"
            autocomplete="new-password" />
        `;
        c.appendChild(div);
        return;
      }

      if (colType === 'date') {
        inputType   = 'date';
        placeholder = 'YYYY-MM-DD';
      } else if (/^(datetime|timestamp)(\(\d+\))?$/.test(colType)) {
        inputType   = 'datetime-local';
        placeholder = 'YYYY-MM-DD HH:MM';
      } else if (/^time(\(\d+\))?$/.test(colType)) {
        inputType   = 'time';
        placeholder = 'HH:MM';
      } else if (/^(tinyint|smallint|mediumint|bigint|int)(\(\d+\))?$/.test(colType) || /^bool(ean)?$/.test(colType)) {
        inputType  = 'number';
        const isBool = /^(bool(ean)?|tinyint\(1\))$/.test(colType);
        if (isBool) {
          extraAttrs  = 'step="1" min="0" max="1"';
          placeholder = '0 o 1';
        } else {
          extraAttrs  = 'step="1"';
          placeholder = 'Solo números enteros';
        }
      } else if (/^(decimal|numeric|float|double|real)(\(\d+,\d+\))?$/.test(colType)) {
        inputType   = 'number';
        extraAttrs  = 'step="any"';
        placeholder = 'Número decimal';
      } else if (colType === 'year' || colType === 'year(4)') {
        inputType   = 'number';
        extraAttrs  = 'step="1" min="1900" max="2100"';
        placeholder = 'YYYY';
      } else {
        inputType = 'text';
        const lenMatch = colType.match(/\((\d+)\)/);
        if (lenMatch) {
          extraAttrs  = `maxlength="${lenMatch[1]}"`;
          placeholder = `Máx. ${lenMatch[1]} caracteres`;
        } else {
          placeholder = col.Type;
        }
      }
      if (val) {
        if (inputType === 'datetime-local') {
          val = String(val).replace(' ', 'T').substring(0, 16);
        } else if (inputType === 'date') {
          val = String(val).substring(0, 10);
        }
      }
      div.innerHTML = `
        <label>${colLabel(name)}</label>
        <input
          data-field="${name}"
          type="${inputType}"
          value="${val}"
          placeholder="${placeholder}"
          ${extraAttrs}
          ${readOnly ? 'readonly' : ''}
        />
      `;
    }
    // [CAM-1] Advertencia individual por campo de cuenta_pasajero
    if (tabla === 'cuenta_pasajero' && CAMPOS_FIREBASE[name]) {
      const fw = CAMPOS_FIREBASE[name];
      const alertDiv = document.createElement('div');
      const bgColor  = fw.nivel === 'peligro' ? '#fff0f0' : '#f0f7ff';
      const bdColor  = fw.nivel === 'peligro' ? '#f87171' : '#93c5fd';
      const txColor  = fw.nivel === 'peligro' ? '#991b1b' : '#1e40af';
      const icon     = fw.nivel === 'peligro' ? '🚫' : 'ℹ️';
      alertDiv.style.cssText = `
        background:${bgColor};border:1px solid ${bdColor};border-radius:6px;
        padding:7px 12px;margin-bottom:2px;font-size:12px;color:${txColor};
        display:flex;gap:8px;align-items:flex-start;line-height:1.5;`;
      alertDiv.innerHTML = `<span style="flex-shrink:0">${icon}</span><span>${fw.msg}</span>`;
      c.appendChild(alertDiv);
    }

    c.appendChild(div);
  });
}

async function submitCrud() {
  const tabla  = tablaActual.nombre;
  const campos = document.querySelectorAll('#crud-form-fields [data-field]');
  const data   = {};
  campos.forEach(el => {
    if (el.readOnly || el.disabled) return;
    const v = el.value.trim();
    const esPassVacio = (el.dataset.field === 'contrasena' || el.dataset.field === 'clave')
                        && v === '' && tablaActual.modo === 'editar';
    if (esPassVacio) return;
    data[el.dataset.field] = v==='' ? null : v;
  });

  // [CAM-3] Validación de fechas para viaje (frontend)
  if (tabla === 'viaje') {
    const salida  = data['fecHoraSalida'] || data['fechorasalida'];
    const llegada = data['fecHoraEntrada'] || data['fechoraentrada'];
    if (salida && llegada) {
      const dtSal = new Date(salida.replace(' ','T'));
      const dtLle = new Date(llegada.replace(' ','T'));
      if (isNaN(dtSal) || isNaN(dtLle)) {
        toast('Formato de fecha inválido.', 'err'); return;
      }
      if (dtLle <= dtSal) {
        toast('⚠️ La llegada debe ser posterior a la salida.', 'err'); return;
      }
    }
  }

  if (tablaActual.modo === 'insertar') {
    // [CAM-PK] Verificar si la PK propuesta está ocupada antes de enviar
    const pkCol = tablaActual.pkCol;
    if (pkCol && data[pkCol] !== null && data[pkCol] !== undefined) {
      const pkVal = String(data[pkCol]).trim();
      if (pkVal !== '') {
        const chk = await fetch(`/api/crud/${tabla}/next_pk/?propuesto=${encodeURIComponent(pkVal)}`).then(r=>r.json());
        if (chk.ok && chk.ocupado) {
          // Mostrar diálogo de confirmación
          const confirmado = await _dialogoPkOcupado(pkVal, chk.next_id);
          if (!confirmado) return;           // usuario canceló
          data[pkCol] = chk.next_id;         // reemplazar con el ID libre
          // Actualizar el campo visible en el formulario
          const inp = document.querySelector(`#crud-form-fields [data-field="${pkCol}"]`);
          if (inp) inp.value = chk.next_id;
        }
      }
    }

    const d = await fetch(`/api/crud/${tabla}/insertar/`,{method:'POST',headers:csrfHeaders(),body:JSON.stringify(data)}).then(r=>r.json());
    d.ok ? (toast('Registro insertado ✓'), cerrarModal('modal-crud'), recargarGestion()) : toast('Error: '+d.error,'err');
  } else {
    data.__pk_name__  = tablaActual.pkName;
    data.__pk_value__ = tablaActual.pkValue;
    const d = await fetch(`/api/crud/${tabla}/actualizar/`,{method:'POST',headers:csrfHeaders(),body:JSON.stringify(data)}).then(r=>r.json());
    d.ok ? (toast('Registro actualizado ✓'), cerrarModal('modal-crud'), recargarGestion()) : toast('Error: '+d.error,'err');
  }
}

// Diálogo de confirmación cuando la PK propuesta ya está ocupada
function _dialogoPkOcupado(pkOcupada, pkLibre) {
  return new Promise(resolve => {
    // Eliminar diálogo previo si existiera
    document.getElementById('_dlg-pk-ocupada')?.remove();

    const dlg = document.createElement('div');
    dlg.id = '_dlg-pk-ocupada';
    dlg.style.cssText = `
      position:fixed;inset:0;z-index:10000;display:flex;align-items:center;justify-content:center;
      background:rgba(0,0,0,.45);`;
    dlg.innerHTML = `
      <div style="background:var(--bg,#fff);border-radius:14px;padding:28px 32px;max-width:380px;
                  width:90%;box-shadow:0 8px 40px rgba(0,0,0,.22);font-family:inherit;">
        <div style="font-size:22px;margin-bottom:10px">⚠️</div>
        <div style="font-weight:700;font-size:16px;margin-bottom:8px;color:var(--text,#1a2b3c)">
          ID ${pkOcupada} ya está en uso
        </div>
        <div style="font-size:14px;color:var(--muted,#6b8fa8);margin-bottom:22px;line-height:1.6">
          El número <b>${pkOcupada}</b> ya existe en la tabla.<br>
          ¿Quieres usar el <b style="color:var(--azul,#1181c3)">${pkLibre}</b> (siguiente disponible)?
        </div>
        <div style="display:flex;gap:10px;justify-content:flex-end">
          <button id="_dlg-pk-cancel"
            style="padding:8px 18px;border-radius:8px;border:1.5px solid var(--border,#e2e8f0);
                   background:transparent;cursor:pointer;font-size:14px;color:var(--text,#1a2b3c)">
            Cancelar
          </button>
          <button id="_dlg-pk-ok"
            style="padding:8px 18px;border-radius:8px;border:none;background:var(--azul,#1181c3);
                   color:#fff;cursor:pointer;font-size:14px;font-weight:600">
            Usar ${pkLibre}
          </button>
        </div>
      </div>`;

    document.body.appendChild(dlg);

    document.getElementById('_dlg-pk-ok').onclick = () => {
      dlg.remove(); resolve(true);
    };
    document.getElementById('_dlg-pk-cancel').onclick = () => {
      dlg.remove(); resolve(false);
    };
    dlg.addEventListener('click', e => {
      if (e.target === dlg) { dlg.remove(); resolve(false); }
    });
  });
}

async function eliminarReg(tabla, pk, pkv) {
  // Guardar contexto para que confirmarEliminar() lo use
  window._elimCtx = { tabla, pk, pkv };

  document.getElementById('modal-elim-tabla').textContent = tabla;
  document.getElementById('modal-elim-pk').textContent    = pkv;

  // Resaltar la opción RESTRICT por defecto (la más segura)
  document.querySelectorAll('.elim-opt').forEach(b => b.classList.remove('active'));
  document.querySelector('.elim-opt[data-modo="restrict"]').classList.add('active');
  window._elimModo = 'restrict';

  abrirModal('modal-eliminar');
}

function selElimModo(modo) {
  window._elimModo = modo;
  document.querySelectorAll('.elim-opt').forEach(b => b.classList.remove('active'));
  document.querySelector(`.elim-opt[data-modo="${modo}"]`).classList.add('active');
}

async function confirmarEliminar() {
  const { tabla, pk, pkv } = window._elimCtx;
  const modo = window._elimModo || 'restrict';
  const d = await fetch(`/api/crud/${tabla}/eliminar/`, {
    method: 'POST',
    headers: csrfHeaders(),
    body: JSON.stringify({ pk_name: pk, pk_value: pkv, modo_eliminar: modo })
  }).then(r => r.json());
  cerrarModal('modal-eliminar');
  d.ok ? (toast('Registro eliminado'), recargarGestion()) : toast('Error: ' + d.error, 'err');
}

function verDetalle(cols, row) {
  document.getElementById('detalle-title').textContent = `Detalle — ${tablaActual.nombre}`;
  document.getElementById('detalle-body').innerHTML    = cols.map(c=>`
    <div style="display:flex;justify-content:space-between;gap:12px;padding:7px 0;border-bottom:1px dashed var(--border)">
      <span style="font-weight:700;color:var(--muted);flex-shrink:0">${colLabel(c)}</span>
      <span style="text-align:right;word-break:break-all">${row[c]??'—'}</span>
    </div>`).join('');
  abrirModal('modal-detalle');
}

// ════ CONFIGURACIÓN ════════════════════

function cargarConfig() {
  document.getElementById('cfg-nombre').value   = TAQ_DATA.nombre;
  document.getElementById('cfg-ap1').value      = TAQ_DATA.ap1;
  document.getElementById('cfg-ap2').value      = TAQ_DATA.ap2;
  document.getElementById('cfg-usuario').value  = TAQ_DATA.usuario;
  document.getElementById('cfg-pass').value       = '';
  document.getElementById('cfg-pass').placeholder = '\u2022\u2022\u2022\u2022\u2022\u2022  (dejar vac\u00edo para no cambiar)';
}

async function guardarConfig() {
  const body = new FormData();
  body.append('nombre',           document.getElementById('cfg-nombre').value.trim());
  body.append('primer_apellido',  document.getElementById('cfg-ap1').value.trim());
  body.append('segundo_apellido', document.getElementById('cfg-ap2').value.trim());
  body.append('usuario',          document.getElementById('cfg-usuario').value.trim());
  const nuevaPass = document.getElementById('cfg-pass').value.trim();
  if (nuevaPass) body.append('contrasena', nuevaPass);
  body.append('csrfmiddlewaretoken', CSRF);
  const d = await fetch('/api/config/',{method:'POST',body}).then(r=>r.json());
  d.ok ? toast('Cambios guardados') : toast('Error: '+d.error,'err');
}

// ════ FOTO TAQUILLERO ══════════════════

function previsualizarFoto(input) {
  const file = input.files[0];
  if (!file) return;
  if (file.size > 5*1024*1024) { toast('La imagen no puede superar 5 MB','err'); return; }
  _fotoFile = file;
  const reader = new FileReader();
  reader.onload = e => {
    const img = document.getElementById('cfg-avatar-img');
    const ph  = document.getElementById('cfg-avatar-ph');
    img.src = e.target.result;
    img.style.display = 'block';
    if (ph) ph.style.display = 'none';
    document.getElementById('cfg-foto-submit').style.display = 'inline-block';
    document.getElementById('cfg-foto-cancel').style.display = 'inline-block';
  };
  reader.readAsDataURL(file);
}

async function subirFoto() {
  if (!_fotoFile) return;
  const form = new FormData();
  form.append('foto', _fotoFile);
  form.append('csrfmiddlewaretoken', CSRF);
  try {
    const r = await fetch(`/api/taquillero/${TAQ_ID}/foto/`,{method:'POST',body:form});
    const d = await r.json();
    if (r.ok) {
      toast('Foto actualizada ✔');
      document.getElementById('cfg-foto-submit').style.display = 'none';
      document.getElementById('cfg-foto-cancel').style.display = 'none';
      _fotoFile = null;
    } else { toast('Error: '+(d.error||'desconocido'),'err'); }
  } catch(e) { toast('Error de conexión','err'); }
}

function cancelarFoto() {
  _fotoFile = null;
  document.getElementById('cfg-foto-input').value        = '';
  document.getElementById('cfg-foto-submit').style.display = 'none';
  document.getElementById('cfg-foto-cancel').style.display = 'none';
  const img = document.getElementById('cfg-avatar-img');
  const ph  = document.getElementById('cfg-avatar-ph');
  if (TAQ_FOTO) {
    img.src = '/media/' + TAQ_FOTO;
  } else {
    img.src = '';
    img.style.display = 'none';
    if (ph) ph.style.display = 'flex';
  }
}

// ════ MODALES ══════════════════════════

const abrirModal  = id => document.getElementById(id).classList.add('open');
const cerrarModal = id => document.getElementById(id).classList.remove('open');

document.querySelectorAll('.modal-overlay').forEach(m =>
  m.addEventListener('click', e => { if (e.target===m) m.classList.remove('open'); })
);

const cerrarSesion = () => { if (confirm('¿Cerrar sesión?')) window.location.href='/logout/'; };

// ── Elipse ─────────────────────────────
(function setupElipse() {
  const btn = document.getElementById('btn-elipse');
  if (!btn) return;
  btn.addEventListener('mouseenter', function onFirst() {
    btn.classList.add('elipse-on');
    btn.removeEventListener('mouseenter', onFirst);
  });
})();

function irAEclipse() { window.location.href = '/elipse/'; }

// ════ INIT ═════════════════════════════
(function init() {
  const h   = today();
  const now = new Date();
  const mes = String(now.getMonth()+1).padStart(2,'0');

  document.getElementById('kg-fecha').value  = h;
  document.getElementById('ke-fecha').value  = h;
  document.getElementById('ke-mes').value    = mes;
  document.getElementById('kg-mes').value    = mes;
  document.getElementById('ke-anio').value   = now.getFullYear();
  document.getElementById('kg-anio').value   = now.getFullYear();

  initPrecisionToggle('sal-precision','sal-precision-track','sal-precision-text','sal-precision-label');

  const sb   = document.getElementById('sidebar');
  const main = document.getElementById('main');
  main.style.marginLeft = isMobile()
    ? '0'
    : sb.classList.contains('collapsed')
      ? 'var(--sidebar-w-collapsed)'
      : 'var(--sidebar-w)';

  showPage('kpi-generales');
})();
// ════════════════════════════════════════════════════════════════
//  REPORTE DE VENTAS
// ════════════════════════════════════════════════════════════════

let rvDatos = null; // guarda última respuesta para CSV

function rvFmt(n) {
  const v = parseFloat(n) || 0;
  return '$' + v.toLocaleString('es-MX', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
}

// Poblar selects de ruta y taquillero la primera vez que se abre el módulo
let rvOpcionesListas = false;
function rvCargarOpciones(data) {
  if (rvOpcionesListas) return;
  const selRuta = document.getElementById('rv-ruta');
  const selTaq  = document.getElementById('rv-taquillero');
  (data.opciones_rutas || []).forEach(r => {
    const o = document.createElement('option');
    o.value = r.value; o.textContent = r.label;
    selRuta.appendChild(o);
  });
  (data.opciones_taquilleros || []).forEach(r => {
    const o = document.createElement('option');
    o.value = r.value; o.textContent = r.label;
    selTaq.appendChild(o);
  });
  rvOpcionesListas = true;
}

function generarReporteVentas() {
  const desde      = document.getElementById('rv-desde').value;
  const hasta      = document.getElementById('rv-hasta').value;
  const rutaId     = document.getElementById('rv-ruta').value;
  const taqId      = document.getElementById('rv-taquillero').value;

  // ── Validación de fechas ──────────────────────────────────────────────
  if (desde && hasta && desde > hasta) {
    // Marcar visualmente
    const elDesde = document.getElementById('rv-desde');
    const elHasta = document.getElementById('rv-hasta');
    elDesde.style.borderColor = '#e53e3e';
    elHasta.style.borderColor = '#e53e3e';
    toast('La fecha de inicio no puede ser mayor que la fecha fin.', 'err');
    setTimeout(() => {
      elDesde.style.borderColor = '';
      elHasta.style.borderColor = '';
    }, 2500);
    return;
  }
  if (!desde && hasta) {
    document.getElementById('rv-desde').style.borderColor = '#e53e3e';
    toast('Ingresa también una fecha de inicio.', 'err');
    setTimeout(() => { document.getElementById('rv-desde').style.borderColor = ''; }, 2500);
    return;
  }
  if (desde && !hasta) {
    document.getElementById('rv-hasta').style.borderColor = '#e53e3e';
    toast('Ingresa también una fecha de fin.', 'err');
    setTimeout(() => { document.getElementById('rv-hasta').style.borderColor = ''; }, 2500);
    return;
  }

  // Mostrar loading
  document.getElementById('rv-empty').style.display     = 'none';
  document.getElementById('rv-resultado').style.display = 'none';
  document.getElementById('rv-loading').style.display   = 'block';
  document.getElementById('rv-btn-csv').style.display   = 'none';

  const params = new URLSearchParams();
  if (desde)  params.set('desde',         desde);
  if (hasta)  params.set('hasta',         hasta);
  if (rutaId) params.set('ruta_id',       rutaId);
  if (taqId)  params.set('taquillero_id', taqId);

  fetch('/api/reporte/ventas/?' + params.toString())
    .then(r => r.json())
    .then(data => {
      rvDatos = data;
      rvCargarOpciones(data);
      rvRenderResumen(data.resumen);
      rvRenderTablaSimple('rv-tabla-ruta',
        data.por_ruta,
        ['ruta', 'boletos', 'ingresos'],
        ['Ruta', 'Boletos', 'Ingresos'],
        { ingresos: true }
      );
      rvRenderTablaSimple('rv-tabla-taquillero',
        data.por_taquillero,
        ['taquillero', 'boletos', 'transacciones', 'ingresos'],
        ['Taquillero', 'Boletos', 'Transacciones', 'Ingresos'],
        { ingresos: true }
      );
      rvRenderTablaSimple('rv-tabla-tipo',
        data.por_tipo,
        ['tipo_pasajero', 'descuento_pct', 'boletos', 'ingresos'],
        ['Tipo', 'Descuento %', 'Boletos', 'Ingresos'],
        { ingresos: true }
      );
      rvRenderDetalle(data.detalle);

      document.getElementById('rv-loading').style.display   = 'none';
      document.getElementById('rv-resultado').style.display = 'block';
      document.getElementById('rv-btn-csv').style.display   = '';
    })
    .catch(err => {
      document.getElementById('rv-loading').style.display = 'none';
      document.getElementById('rv-empty').style.display   = 'block';
      toast('Error al generar el reporte: ' + err.message, 'err');
    });
}

function rvRenderResumen(r) {
  if (!r) return;
  const totalRec  = parseFloat(r.ingresos_totales) || 0;
  const efectivo  = parseFloat(r.total_efectivo)   || 0;
  const tarjeta   = parseFloat(r.total_tarjeta)    || 0;
  // Calcular % solo sobre la base real (efectivo + tarjeta), no sobre ingresos_totales
  const baseReal  = efectivo + tarjeta;
  const pctEfec   = baseReal > 0 ? Math.round(efectivo / baseReal * 100) : 0;
  const pctTarj   = baseReal > 0 ? (100 - pctEfec) : 0;
  const splitLabel = baseReal > 0
    ? `${pctEfec}% efectivo · ${pctTarj}% tarjeta`
    : 'Sin transacciones';

  document.getElementById('rv-resumen-cards').innerHTML = `
    <div class="eco-stat-card eco-green">
      <div class="eco-stat-icon">💵</div>
      <div class="eco-stat-body">
        <div class="eco-stat-label">Ingresos totales</div>
        <div class="eco-stat-value">${rvFmt(r.ingresos_totales)}</div>
        <div class="eco-stat-sub">${r.total_transacciones || 0} transacciones</div>
      </div>
    </div>
    <div class="eco-stat-card eco-blue">
      <div class="eco-stat-icon">🎫</div>
      <div class="eco-stat-body">
        <div class="eco-stat-label">Boletos vendidos</div>
        <div class="eco-stat-value">${r.total_boletos || 0}</div>
        <div class="eco-stat-sub">Promedio ${rvFmt(r.promedio_boleto)} / boleto</div>
      </div>
    </div>
    <div class="eco-stat-card eco-orange">
      <div class="eco-stat-icon">💳</div>
      <div class="eco-stat-body">
        <div class="eco-stat-label">Efectivo vs Tarjeta</div>
        <div class="eco-split-row">
          <div class="eco-split-item">
            <span class="eco-split-dot dot-cash"></span>
            <span class="eco-split-label">Efectivo</span>
            <span class="eco-split-val">${rvFmt(r.total_efectivo)}</span>
          </div>
          <div class="eco-split-item">
            <span class="eco-split-dot dot-card"></span>
            <span class="eco-split-label">Tarjeta</span>
            <span class="eco-split-val">${rvFmt(r.total_tarjeta)}</span>
          </div>
        </div>
        <div class="eco-bar-split">
          <div class="eco-bar-efectivo" style="width:${pctEfec}%"></div>
          <div class="eco-bar-tarjeta"  style="width:${pctTarj}%"></div>
        </div>
        <div class="eco-stat-sub">${splitLabel}</div>
      </div>
    </div>
  `;
}

function rvRenderTablaSimple(tableId, rows, keys, headers, moneyKeys) {
  const tbody = document.querySelector('#' + tableId + ' tbody');
  if (!rows || rows.length === 0) {
    tbody.innerHTML = '<tr><td colspan="' + keys.length + '" style="text-align:center;color:var(--muted);padding:16px;">Sin datos</td></tr>';
    return;
  }
  tbody.innerHTML = rows.map(r =>
    '<tr>' + keys.map(k => {
      const val = r[k] !== null && r[k] !== undefined ? r[k] : '—';
      const isMoney = moneyKeys && moneyKeys[k];
      if (isMoney) return `<td class="rv-monto">${rvFmt(val)}</td>`;
      return `<td>${val}</td>`;
    }).join('') + '</tr>'
  ).join('');
}

function rvRenderDetalle(rows) {
  const tbody = document.querySelector('#rv-tabla-detalle tbody');
  if (!rows || rows.length === 0) {
    tbody.innerHTML = '<tr><td colspan="7" style="text-align:center;color:var(--muted);padding:16px;">Sin datos</td></tr>';
    return;
  }
  tbody.innerHTML = rows.map(r => `
    <tr>
      <td><span class="rv-folio">#${r.folio}</span></td>
      <td>${r.fecha || '—'}</td>
      <td>${r.ruta || '—'}</td>
      <td>${r.taquillero || '—'}</td>
      <td>${r.metodo_pago || '—'}</td>
      <td>${r.boletos || 0}</td>
      <td class="rv-monto">${rvFmt(r.monto)}</td>
    </tr>
  `).join('');
}

function limpiarReporteVentas() {
  document.getElementById('rv-desde').value    = '';
  document.getElementById('rv-hasta').value    = '';
  document.getElementById('rv-ruta').value     = '';
  document.getElementById('rv-taquillero').value = '';
  document.getElementById('rv-resultado').style.display = 'none';
  document.getElementById('rv-btn-csv').style.display   = 'none';
  document.getElementById('rv-empty').style.display     = 'block';
  rvDatos = null;
}

function exportarReporteCSV() {
  if (!rvDatos) return;

  const desde = document.getElementById('rv-desde').value || 'todo';
  const hasta = document.getElementById('rv-hasta').value || 'todo';

  // ── Hoja 1: Resumen ──────────────────────────────────────────
  const r = rvDatos.resumen || {};
  let csv = 'REPORTE DE VENTAS\n';
  csv += `Período:,${desde} al ${hasta}\n\n`;
  csv += 'RESUMEN GENERAL\n';
  csv += 'Concepto,Valor\n';
  csv += `Ingresos totales,"${rvFmt(r.ingresos_totales)}"\n`;
  csv += `Total boletos vendidos,${r.total_boletos || 0}\n`;
  csv += `Total transacciones,${r.total_transacciones || 0}\n`;
  csv += `Promedio por boleto,"${rvFmt(r.promedio_boleto)}"\n`;
  csv += `Total efectivo,"${rvFmt(r.total_efectivo)}"\n`;
  csv += `Total tarjeta,"${rvFmt(r.total_tarjeta)}"\n\n`;

  // ── Hoja 2: Por ruta ─────────────────────────────────────────
  csv += 'DESGLOSE POR RUTA\n';
  csv += 'Ruta,Boletos,Ingresos\n';
  (rvDatos.por_ruta || []).forEach(row => {
    csv += `"${row.ruta}",${row.boletos},"${rvFmt(row.ingresos)}"\n`;
  });
  csv += '\n';

  // ── Hoja 3: Por taquillero ───────────────────────────────────
  csv += 'DESGLOSE POR TAQUILLERO\n';
  csv += 'Taquillero,Boletos,Transacciones,Ingresos\n';
  (rvDatos.por_taquillero || []).forEach(row => {
    csv += `"${row.taquillero}",${row.boletos},${row.transacciones},"${rvFmt(row.ingresos)}"\n`;
  });
  csv += '\n';

  // ── Hoja 4: Por tipo de pasajero ─────────────────────────────
  csv += 'DESGLOSE POR TIPO DE PASAJERO\n';
  csv += 'Tipo,Descuento %,Boletos,Ingresos\n';
  (rvDatos.por_tipo || []).forEach(row => {
    csv += `"${row.tipo_pasajero}",${row.descuento_pct}%,${row.boletos},"${rvFmt(row.ingresos)}"\n`;
  });
  csv += '\n';

  // ── Hoja 5: Detalle ──────────────────────────────────────────
  csv += 'DETALLE DE VENTAS\n';
  csv += 'Folio,Fecha,Ruta,Taquillero,Método Pago,Boletos,Monto\n';
  (rvDatos.detalle || []).forEach(row => {
    csv += `${row.folio},"${row.fecha}","${row.ruta}","${row.taquillero}","${row.metodo_pago}",${row.boletos},"${rvFmt(row.monto)}"\n`;
  });

  // ── Descarga ─────────────────────────────────────────────────
  const blob = new Blob(['\ufeff' + csv], { type: 'text/csv;charset=utf-8;' });
  const url  = URL.createObjectURL(blob);
  const a    = document.createElement('a');
  a.href     = url;
  a.download = `reporte_ventas_${desde}_${hasta}.csv`;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
  toast('CSV descargado correctamente', 'ok');
}

// Cargar opciones del reporte la primera vez que se abre la página
// (sin ejecutar el reporte — solo poblar los selects)
function rvIniciarOpciones() {
  // Pre-llenar fechas con el mes actual si están vacías
  const elDesde = document.getElementById('rv-desde');
  const elHasta = document.getElementById('rv-hasta');
  if (!elDesde.value) {
    const now  = new Date();
    const yyyy = now.getFullYear();
    const mm   = String(now.getMonth() + 1).padStart(2, '0');
    const dd   = String(now.getDate()).padStart(2, '0');
    const primerDia = `${yyyy}-${mm}-01`;
    const hoy       = `${yyyy}-${mm}-${dd}`;
    elDesde.value = primerDia;
    elHasta.value = hoy;
  }

  // Validación en tiempo real: no dejar fecha fin menor a fecha inicio
  elDesde.addEventListener('change', () => {
    if (elHasta.value && elDesde.value > elHasta.value) {
      elHasta.value = elDesde.value;
    }
    elDesde.style.borderColor = '';
    elHasta.style.borderColor = '';
  });
  elHasta.addEventListener('change', () => {
    if (elDesde.value && elHasta.value < elDesde.value) {
      elHasta.value = elDesde.value;
      toast('La fecha fin se ajustó para no ser menor a la fecha inicio.', 'ok');
    }
    elDesde.style.borderColor = '';
    elHasta.style.borderColor = '';
  });

  if (rvOpcionesListas) return;
  fetch('/api/reporte/ventas/')
    .then(r => r.json())
    .then(data => rvCargarOpciones(data))
    .catch(() => {});
}