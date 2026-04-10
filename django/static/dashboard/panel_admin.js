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
let rutasDuracion      = {};   // FIX: declarado correctamente con let desde el principio
let _fotoFile          = null;
let gestionView        = 'tabla';   // 'tabla' | 'cards'
let gestionLastData    = null;      // cache para re-render sin re-fetch
let gestionModo        = 'db';      // 'db' | 'legible'

// ── Helpers ────────────────────────────
const csrfHeaders = () => ({ 'Content-Type':'application/json', 'X-CSRFToken': CSRF });
const fmt   = dt => dt ? dt.replace('T',' ').substring(0,16) : '—';
const today = ()  => new Date().toISOString().split('T')[0];

// FIX: helper para formatear fecha local sin conversión UTC
function toLocalDatetimeString(date) {
  const pad = n => String(n).padStart(2,'0');
  return `${date.getFullYear()}-${pad(date.getMonth()+1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

// FIX: parsear string datetime-local como hora LOCAL (no UTC)
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
    'salidas'         : 'Salidas',
    'historial'       : 'Historial de Viajes',
    'gestion'         : 'Gestión',
    'configuracion'   : 'Configuración'
  }[id] || id;
  if (id==='salidas')         cargarSalidas();
  if (id==='historial')       cargarHistorial();
  if (id==='kpi-generales')   cargarKpiGenerales();
  if (id==='kpi-especificos') { cargarKpiOpciones(); cargarKpiEspecificos(false); }
  if (id==='configuracion')   cargarConfig();
  afterNav();
}

function showGestion(tabla) {
  showPage('gestion');
  document.getElementById('gestion-title').textContent =
    'Gestión — ' + tabla.charAt(0).toUpperCase() + tabla.slice(1);
  tablaActual.nombre = tabla;
  // Si la nueva tabla no tiene modo legible, forzar DB
  if (!TABLAS_CON_LEGIBLE.has(tabla)) gestionModo = 'db';
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
  cargarKpiEspecificos(false);
}

async function cargarKpiOpciones() {
  const d = await fetch('/api/kpi/filtros/').then(r=>r.json());
  fillSelect('ke-conductor', d.conductores, 'Todos');
  fillSelect('ke-autobus',   d.autobuses,   'Todos');
  fillSelect('ke-ciudad',    d.ciudades,    'Todas');
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
  const d = await fetch(url).then(r=>r.json());
  keData  = d.rows;
  renderKeTablo(tipo, d.rows);
}

function renderKeTablo(tipo, rows) {
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
  tbl.querySelector('thead').innerHTML =
    `<tr>${h.map(x=>`<th>${x}</th>`).join('')}</tr>`;
  tbl.querySelector('tbody').innerHTML =
    rows.map(r=>`<tr>${map(r).map(v=>`<td>${v??'—'}</td>`).join('')}</tr>`).join('') ||
    `<tr><td colspan="${h.length}" style="text-align:center;color:var(--muted);padding:24px">Sin datos</td></tr>`;
  document.getElementById('ke-info').textContent = `Resultados: ${rows.length} registro(s)`;
}

function exportarCSV() {
  if (!keData.length) { toast('No hay datos','err'); return; }
  const tipo = document.getElementById('ke-tipo').value;
  const hd   = Object.keys(keData[0]);
  const csv  = [hd.join(','),
    ...keData.map(r=>hd.map(h=>`"${(r[h]??'').toString().replace(/"/g,'""')}"`).join(','))].join('\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv],{type:'text/csv'}));
  a.download = `kpi_${tipo}.csv`;
  a.click();
}

// ════ SALIDAS ══════════════════════════

async function cargarSalidas() {
  document.getElementById('salidas-container').innerHTML = '<span class="spinner"></span>';
  const d  = await fetch('/api/salidas/').then(r=>r.json());
  salidasData = d.rows || [];
  // Poblar selects con todas las ciudades que aparecen como origen O destino
  const todasCiudades = [...new Set([
    ...salidasData.map(r=>r.origen_ciudad),
    ...salidasData.map(r=>r.destino_ciudad)
  ].filter(Boolean))].sort();
  const selOrig = document.getElementById('sal-origen');
  const selDest = document.getElementById('sal-destino');
  selOrig.innerHTML = '<option value="">-- Todas --</option>' + todasCiudades.map(c=>`<option value="${c}">${c}</option>`).join('');
  selDest.innerHTML = '<option value="">-- Todas --</option>' + todasCiudades.map(c=>`<option value="${c}">${c}</option>`).join('');
  document.getElementById('sal-fecha').value = today();
  // Auto-seleccionar ciudad del taquillero en origen al primer cargue
  if (TAQ_DATA.ciudad) {
    const match = [...selOrig.options].find(o => o.value.toLowerCase() === TAQ_DATA.ciudad.toLowerCase());
    if (match) selOrig.value = match.value;
  }
  aplicarFiltrosSalidas();
}

function poblarFiltrosSalidas() {
  // No-op: la población ahora se hace en cargarSalidas para no pisar el filtro activo
}

// Cuando cambia origen: excluir esa misma ciudad del destino
function onSalOrigenChange() {
  const origenVal = document.getElementById('sal-origen').value.toLowerCase();
  const selDest   = document.getElementById('sal-destino');
  const prevDest  = selDest.value;
  const todasCiudades = [...new Set([
    ...salidasData.map(r=>r.origen_ciudad),
    ...salidasData.map(r=>r.destino_ciudad)
  ].filter(Boolean))].sort();
  // Excluir la ciudad seleccionada como origen
  const opciones = origenVal
    ? todasCiudades.filter(c => c.toLowerCase() !== origenVal)
    : todasCiudades;
  selDest.innerHTML = '<option value="">-- Todas --</option>' + opciones.map(c=>`<option value="${c}">${c}</option>`).join('');
  // Restaurar destino previo si sigue siendo válido
  if (prevDest && prevDest.toLowerCase() !== origenVal) selDest.value = prevDest;
  aplicarFiltrosSalidas();
}

let salidasView = 'cards';

function setSalidasView(v) {
  salidasView = v;
  document.getElementById('sal-vbtn-cards').classList.toggle('active', v === 'cards');
  document.getElementById('sal-vbtn-tabla').classList.toggle('active', v === 'tabla');
  // Re-render con los datos actuales
  const trips = salidasData.filter(r => {
    const origenSel = document.getElementById('sal-origen').value.trim().toLowerCase();
    const destSel   = document.getElementById('sal-destino').value.trim().toLowerCase();
    return (!origenSel || (r.origen_ciudad||'').toLowerCase() === origenSel)
        && (!destSel   || (r.destino_ciudad||'').toLowerCase() === destSel);
  });
  aplicarFiltrosSalidas();
}

function aplicarFiltrosSalidas() {
  const fechaSel  = document.getElementById('sal-fecha').value;
  const origenSel = document.getElementById('sal-origen').value.trim().toLowerCase();
  // FIX: usar siempre destino_ciudad (era inconsistente: a veces dest_city, a veces destino_ciudad)
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
    // Ocultar columna Origen siempre que haya un solo origen (ya se muestra arriba en el header)
    // Ocultar columna Destino cuando hay un solo destino (filtro activo o solo uno)
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

  // FIX: limpiar y reconstruir rutasDuracion correctamente
  rutasDuracion = {};
  d.rutas.forEach(r => { rutasDuracion[String(r.value)] = r.duracion || ''; });

  fillSelect('mv-ruta',      d.rutas,      'Seleccionar...');
  fillSelect('mv-autobus',   d.autobuses,  'Seleccionar...');
  fillSelect('mv-conductor', d.conductores,'Seleccionar...');
  fillSelect('mv-estado',    d.estados,    'Seleccionar...');

  // FIX: usar toLocalDatetimeString para que la hora del input sea hora local
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

  // FIX: parsear como hora local (no UTC) para que el cálculo sea correcto
  const salida = parseDatetimeLocal(salidaStr);
  if (!salida || isNaN(salida.getTime())) {
    displayEl.value = 'Fecha de salida inválida';
    hiddenEl.value  = '';
    return;
  }

  const llegada = new Date(salida.getTime() + minutos * 60000);

  // FIX: guardar en hora local, no en UTC
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

  // Formato HH:MM  →  "2:30", "0:45"
  if (/^\d+:\d+$/.test(dur)) {
    const [h, m] = dur.split(':').map(Number);
    return (h * 60) + (m || 0);
  }

  // Formato Xh Ym  →  "2h50m", "0h45m", "3h", "45m", "1h15m"
  const hMatch  = dur.match(/(\d+)\s*h/);
  const mMatch  = dur.match(/(\d+)\s*m/);
  const horas   = hMatch ? parseInt(hMatch[1]) : 0;
  const minutos = mMatch ? parseInt(mMatch[1]) : 0;
  if (hMatch || mMatch) return (horas * 60) + minutos;

  // Fallback: número solo → minutos directos
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
        '<div class="empty-state"><p>Sesi\u00f3n expirada. <a href="/login/">Vuelve a iniciar sesi\u00f3n</a>.</p></div>';
      return;
    }
    if (!res.ok) {
      document.getElementById('hist-cards-container').innerHTML =
        `<div class="empty-state"><p>Error del servidor (${res.status}). Intenta recargar la p\u00e1gina.</p></div>`;
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

    document.getElementById('hist-estado').innerHTML =
      '<option value="">Todos</option>' + uniq(r => r.estado).map(v => `<option value="${v}">${v}</option>`).join('');

    // Poblar origen con todas las ciudades
    const selOrig = document.getElementById('hist-origen');
    selOrig.innerHTML = '<option value="">-- Todas --</option>' +
      todasCiudades.map(c => `<option value="${c}">${c}</option>`).join('');

    // Poblar destino (inicialmente todas)
    const selDest = document.getElementById('hist-destino');
    selDest.innerHTML = '<option value="">-- Todas --</option>' +
      todasCiudades.map(c => `<option value="${c}">${c}</option>`).join('');

    // Auto-seleccionar ciudad del taquillero en origen
    if (TAQ_DATA.ciudad) {
      const match = [...selOrig.options].find(o => o.value.toLowerCase() === TAQ_DATA.ciudad.toLowerCase());
      if (match) {
        selOrig.value = match.value;
        // Excluir esa ciudad del destino
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

// Actualiza las opciones del select destino excluyendo la ciudad de origen seleccionada
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

  // Restaurar destino previo si sigue siendo válido
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
  historialBase = historialData.filter(r => {
    const txt = [r.origen_ciudad,r.destino_ciudad,r.conductor,r.autobus_placas,String(r.numero),String(r.autobus_num)].join(' ').toLowerCase();
    return txt.includes(q) && (!es||r.estado===es) && (!or||r.origen_ciudad===or) && (!de||r.destino_ciudad===de);
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
  renderHistorialCards(rows);
}

function limpiarFiltrosHistorial() {
  ['hist-search','hist-estado','hist-fecha'].forEach(id=>{
    document.getElementById(id).value = '';
  });
  const cb    = document.getElementById('hist-precision');
  const track = document.getElementById('hist-precision-track');
  const txt   = document.getElementById('hist-precision-text');
  if (cb)    cb.checked = false;
  if (track) track.classList.remove('active');
  if (txt)   txt.innerHTML = 'Precisión: <b>Cercana</b>';

  // Restaurar origen a la ciudad del taquillero
  const selOrig = document.getElementById('hist-origen');
  selOrig.value = '';
  if (TAQ_DATA.ciudad) {
    const match = [...selOrig.options].find(o => o.value.toLowerCase() === TAQ_DATA.ciudad.toLowerCase());
    if (match) selOrig.value = match.value;
  }
  // Actualizar destinos excluyendo el origen restaurado
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

function renderHistorialCards(rows) {
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

// Columnas que se omiten en la vista tarjetas por ser poco legibles o redundantes
const COLS_OCULTAS_CARDS = new Set(['serieVIN', 'serievin', 'firebase_uid', 'clave', 'contrasena']);

function setGestionView(view) {
  gestionView = view;
  document.getElementById('gvt-tabla').classList.toggle('active', view === 'tabla');
  document.getElementById('gvt-cards').classList.toggle('active', view === 'cards');
  document.getElementById('gestion-tabla-wrap').style.display = view === 'tabla' ? '' : 'none';
  document.getElementById('gestion-cards-wrap').style.display = view === 'cards' ? '' : 'none';
  // Re-renderizar con datos cacheados si los hay
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

// ════ TOGGLE DB / LEGIBLE ═══════════════
// Tablas que tienen modo legible implementado en el backend
const TABLAS_CON_LEGIBLE = new Set([
  'modelo', 'ruta', 'viaje', 'asiento', 'viaje_asiento',
  'taquillero', 'ticket', 'pago'
]);

function onDbToggleChange() {
  const chk = document.getElementById('db-toggle-chk');

  // Si intenta activar legible en tabla sin soporte → revertir y avisar
  if (chk.checked && !TABLAS_CON_LEGIBLE.has(tablaActual.nombre)) {
    chk.checked = false;
    toast('No es necesario este modo aquí', 'err');
    return;
  }

  gestionModo = chk.checked ? 'legible' : 'db';

  // Actualizar estilos de labels
  document.getElementById('db-toggle-lbl-db').classList.toggle('active', !chk.checked);
  document.getElementById('db-toggle-lbl-leg').classList.toggle('active', chk.checked);

  // Recargar datos con el nuevo modo
  recargarGestion();
}

function _syncDbToggleUI() {
  const chk = document.getElementById('db-toggle-chk');
  chk.checked = (gestionModo === 'legible');
  document.getElementById('db-toggle-lbl-db').classList.toggle('active', gestionModo !== 'legible');
  document.getElementById('db-toggle-lbl-leg').classList.toggle('active', gestionModo === 'legible');
  document.getElementById('db-toggle-wrap').style.display = 'flex';
}

async function recargarGestion() {
  const tabla = tablaActual.nombre;
  if (!tabla) return;
  // Mostrar buscador y toggle
  document.getElementById('gestion-search-wrap').style.display = '';
  _syncDbToggleUI();
  // Limpiar búsqueda al recargar
  const inp = document.getElementById('gestion-search');
  inp.value = '';
  document.getElementById('gestion-search-clear').style.display = 'none';
  // Mostrar spinner en la vista activa
  document.getElementById('gestion-tbody').innerHTML = '<tr><td colspan="20"><span class="spinner"></span></td></tr>';
  document.getElementById('gestion-cards-wrap').innerHTML = '<div style="text-align:center;padding:40px"><span class="spinner"></span></div>';

  const url = `/api/crud/${tabla}/leer/?modo=${gestionModo}`;
  const d = await fetch(url).then(r=>r.json());
  if (d.error) { toast(d.error,'err'); return; }

  gestionLastData = d;

  // Badge de modo en el info-bar
  const badge = `<span class="modo-badge ${gestionModo}">${gestionModo === 'legible' ? '🔤 Legible' : '🗄 DB'}</span>`;
  document.getElementById('gestion-info').innerHTML = `${d.rows.length} registro(s)${badge}`;

  if (gestionView === 'tabla') renderGestionTabla(d);
  else                         renderGestionCards(d);
}

// ════ BUSCADOR DE GESTIÓN ════════════════
function _infoBadge() {
  return `<span class="modo-badge ${gestionModo}">${gestionModo === 'legible' ? '🔤 Legible' : '🗄 DB'}</span>`;
}

function filtrarGestion() {
  const q = document.getElementById('gestion-search').value.trim().toLowerCase();
  document.getElementById('gestion-search-clear').style.display = q ? '' : 'none';

  if (!gestionLastData) return;

  if (!q) {
    // Sin búsqueda: mostrar todo sin highlights
    if (gestionView === 'tabla') renderGestionTabla(gestionLastData);
    else                         renderGestionCards(gestionLastData);
    document.getElementById('gestion-info').innerHTML = `${gestionLastData.rows.length} registro(s)${_infoBadge()}`;
    return;
  }

  // Filtrar filas que tengan al menos una celda que contenga el término
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

// Resalta el término buscado dentro de un texto
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
    `<tr>${d.cols.map(c=>`<th>${c}</th>`).join('')}<th>Acciones</th></tr>`;
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

    // Foto si existe
    const fotoCol = d.cols.find(c => COLS_IMAGEN.has(c));
    const fotoVal = fotoCol ? row[fotoCol] : null;
    const fotoHtml = fotoVal && fotoVal !== '—'
      ? `<img class="gc-card-foto" src="${fotoVal.startsWith('http') ? fotoVal : '/media/'+fotoVal}"
           onerror="this.style.display='none'" onclick="verFotoGrande('${fotoVal.startsWith('http') ? fotoVal : '/media/'+fotoVal}')">`
      : '';

    // Campos visibles (excluir PK, foto, y cols ocultas)
    const camposCols = d.cols.filter(c =>
      c !== pk &&
      !COLS_IMAGEN.has(c) &&
      !COLS_OCULTAS_CARDS.has(c)
    );

    const camposHtml = camposCols.map(c => `
      <div class="gc-field">
        <span class="gc-field-key">${c}</span>
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
    const esq   = await fetch(`/api/crud/${tabla}/esquema/`).then(r=>r.json());
    const datos = await fetch(`/api/crud/${tabla}/leer/`).then(r=>r.json());
    const pkCol = esq.columnas.find(c => c.Key === 'PRI')?.Field;

    let nextId = '';
    if (pkCol && datos.rows?.length) {
      const max = Math.max(...datos.rows.map(r => parseInt(r[pkCol]) || 0));
      nextId = max + 1;
    } else {
      nextId = 1;
    }

    tablaActual.esquema = esq;
    tablaActual.modo    = 'insertar';
    tablaActual.nextId  = nextId;

    document.getElementById('crud-modal-title').textContent  = `Insertar en ${tabla}`;
    document.getElementById('crud-submit-btn').textContent   = 'Insertar';

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

function renderCrudForm(esq, vals) {
  const c = document.getElementById('crud-form-fields');
  c.innerHTML = '';

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

    // ── FOREIGN KEYS ───────────────────
    if (esq.fk_map[name]) {
      const opts = esq.opciones[name] || [];
      div.innerHTML = `
        <label>${name}</label>
        <select data-field="${name}" ${isPK && isEditing ? 'disabled' : ''}>
          <option value="">— seleccionar —</option>
          ${opts.map(o => `
            <option value="${o.value}" ${String(o.value) === String(val) ? 'selected' : ''}>
              ${o.label}
            </option>`).join('')}
        </select>
      `;
    }
    // ── INPUT CON TIPO ESTRICTO POR COLUMNA ───────────────────
    else {
      const readOnly = isPK && isEditing;
      const colType  = col.Type.toLowerCase();

      let inputType  = 'text';
      let extraAttrs = '';
      let placeholder = '';

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

      // ── Formatear valor existente para inputs de fecha ──
      if (val) {
        if (inputType === 'datetime-local') {
          val = String(val).replace(' ', 'T').substring(0, 16);
        } else if (inputType === 'date') {
          val = String(val).substring(0, 10);
        }
      }

      div.innerHTML = `
        <label>${name}</label>
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
    data[el.dataset.field] = v==='' ? null : v;
  });
  if (tablaActual.modo==='insertar') {
    const d = await fetch(`/api/crud/${tabla}/insertar/`,{method:'POST',headers:csrfHeaders(),body:JSON.stringify(data)}).then(r=>r.json());
    d.ok ? (toast('Registro insertado'), cerrarModal('modal-crud'), recargarGestion()) : toast('Error: '+d.error,'err');
  } else {
    data.__pk_name__  = tablaActual.pkName;
    data.__pk_value__ = tablaActual.pkValue;
    const d = await fetch(`/api/crud/${tabla}/actualizar/`,{method:'POST',headers:csrfHeaders(),body:JSON.stringify(data)}).then(r=>r.json());
    d.ok ? (toast('Registro actualizado'), cerrarModal('modal-crud'), recargarGestion()) : toast('Error: '+d.error,'err');
  }
}

async function eliminarReg(tabla, pk, pkv) {
  if (!confirm(`¿Eliminar el registro ${pkv} de ${tabla}?`)) return;
  const d = await fetch(`/api/crud/${tabla}/eliminar/`,{method:'POST',headers:csrfHeaders(),body:JSON.stringify({pk_name:pk,pk_value:pkv})}).then(r=>r.json());
  d.ok ? (toast('Registro eliminado'), recargarGestion()) : toast('Error: '+d.error,'err');
}

function verDetalle(cols, row) {
  document.getElementById('detalle-title').textContent = `Detalle — ${tablaActual.nombre}`;
  document.getElementById('detalle-body').innerHTML    = cols.map(c=>`
    <div style="display:flex;justify-content:space-between;gap:12px;padding:7px 0;border-bottom:1px dashed var(--border)">
      <span style="font-weight:700;color:var(--muted);flex-shrink:0">${c}</span>
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
  document.getElementById('cfg-pass').value     = TAQ_DATA.contrasena;
}

async function guardarConfig() {
  const body = new FormData();
  body.append('nombre',           document.getElementById('cfg-nombre').value.trim());
  body.append('primer_apellido',  document.getElementById('cfg-ap1').value.trim());
  body.append('segundo_apellido', document.getElementById('cfg-ap2').value.trim());
  body.append('usuario',          document.getElementById('cfg-usuario').value.trim());
  body.append('contrasena',       document.getElementById('cfg-pass').value.trim());
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