/* ════════════════════════════════════════════════════════
   MAPA EN VIVO — RBE
   django/static/dashboard/mapa.js
════════════════════════════════════════════════════════ */

/* ── Coordenadas centrales de cada ciudad de Baja California ── */
const BC_COORDS = {
  'Tijuana':     [32.5149, -117.0382],
  'Mexicali':    [32.6245, -115.4523],
  'Ensenada':    [31.8667, -116.5960],
  'Tecate':      [32.5735, -116.6270],
  'Rosarito':    [32.3732, -117.0381],
  'San Quintín': [30.5380, -115.9500],
  'San Quintin': [30.5380, -115.9500],
  'San Felipe':  [31.0167, -114.8333],
};

function coordsCiudad(nombre) {
  if (!nombre) return null;
  if (BC_COORDS[nombre]) return BC_COORDS[nombre];
  const key = Object.keys(BC_COORDS).find(k =>
    k.toLowerCase().includes(nombre.toLowerCase()) ||
    nombre.toLowerCase().includes(k.toLowerCase())
  );
  return key ? BC_COORDS[key] : null;
}

/* ── Parsear duración "2h50m" → milisegundos ── */
function parseDuracion(str) {
  if (!str) return 0;
  const h = parseInt(str.match(/(\d+)h/)?.[1] || 0);
  const m = parseInt(str.match(/(\d+)m/)?.[1] || 0);
  return (h * 60 + m) * 60 * 1000;
}

/* ════════════════════════════════════════════════════════
   ESTADO GLOBAL
════════════════════════════════════════════════════════ */
let mapaLeaflet     = null;
let mapaInitialized = false;
let mapaAnimId      = null;
let mapaViajes      = {};   // { numero: { marker, linea, datos, progreso } }

/* ════════════════════════════════════════════════════════
   INICIALIZAR
════════════════════════════════════════════════════════ */
function inicializarMapa() {
  if (mapaInitialized) {
    // Si ya existe, solo refrescar datos
    cargarViajesMapa();
    return;
  }
  mapaInitialized = true;

  mapaLeaflet = L.map('mapa-leaflet', {
    center: [31.2, -115.8],
    zoom: 7,
    zoomControl: true,
    attributionControl: true,
  });

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    maxZoom: 19,
  }).addTo(mapaLeaflet);

  cargarViajesMapa();
  setInterval(cargarViajesMapa, 60_000);

  window.addEventListener('offline', () =>
    document.getElementById('mapa-offline-banner')?.classList.add('visible'));
  window.addEventListener('online',  () => {
    document.getElementById('mapa-offline-banner')?.classList.remove('visible');
    cargarViajesMapa();
  });

  if (!navigator.onLine)
    document.getElementById('mapa-offline-banner')?.classList.add('visible');
}

/* ════════════════════════════════════════════════════════
   FETCH
════════════════════════════════════════════════════════ */
async function cargarViajesMapa() {
  const btn = document.getElementById('mapa-btn-refresh');
  btn?.classList.add('girando');

  try {
    const res  = await fetch('/api/salidas/');
    if (!res.ok) throw new Error('HTTP ' + res.status);
    const data = await res.json();
    procesarViajes(data.rows || []);
  } catch (e) {
    console.warn('[Mapa] Sin conexión o error de API:', e.message);
    // Mapa sigue funcionando con tiles cacheados y viajes anteriores
  } finally {
    btn?.classList.remove('girando');
  }
}

/* ════════════════════════════════════════════════════════
   PROCESAR VIAJES → MARCADORES + RUTAS
════════════════════════════════════════════════════════ */
function procesarViajes(rows) {
  const activos = new Set();

  rows.forEach(v => {
    const orig = coordsCiudad(v.origen_ciudad);
    const dest = coordsCiudad(v.destino_ciudad);
    if (!orig || !dest) return;

    const id       = v.numero;
    const progreso = calcularProgreso(v.fecHoraSalida, v.fecHoraEntrada, v.duracion_ruta);
    activos.add(id);

    if (mapaViajes[id]) {
      // Actualizar datos sin recrear objetos
      mapaViajes[id].datos    = v;
      mapaViajes[id].orig     = orig;
      mapaViajes[id].dest     = dest;
      mapaViajes[id].progreso = progreso;
    } else {
      // Línea de ruta — clickeable
      const linea = L.polyline([orig, dest], {
        color:     '#1181c3',
        weight:    3,
        opacity:   0.35,
        dashArray: '8 6',
      }).addTo(mapaLeaflet);

      linea.on('click', () => abrirPopupLinea(id));

      // Marcador del autobús
      const pos    = interpolar(orig, dest, progreso);
      const marker = L.marker(pos, { icon: iconoBus(v), zIndexOffset: 100 })
        .addTo(mapaLeaflet);

      marker.on('click', () => abrirPopupLinea(id));

      mapaViajes[id] = { marker, linea, datos: v, orig, dest, progreso };
    }
  });

  // Eliminar viajes que ya no están en ruta
  Object.keys(mapaViajes).forEach(id => {
    if (!activos.has(Number(id))) {
      mapaViajes[id].marker.remove();
      mapaViajes[id].linea.remove();
      delete mapaViajes[id];
    }
  });

  actualizarContador(activos.size);

  // Arrancar animación si no corre
  if (!mapaAnimId) animLoop();
}

/* ════════════════════════════════════════════════════════
   POPUP AL HACER CLICK EN LÍNEA O MARCADOR
════════════════════════════════════════════════════════ */
function abrirPopupLinea(id) {
  const m = mapaViajes[id];
  if (!m) return;
  const v   = m.datos;
  const pct = Math.round(m.progreso * 100);
  const pos = interpolar(m.orig, m.dest, m.progreso);

  L.popup({ maxWidth: 280, className: 'mapa-popup-wrap' })
    .setLatLng(pos)
    .setContent(`
      <div class="mapa-popup">
        <div class="mapa-popup-titulo">
          🚌 Bus #${v.autobus_num || '—'}
          <span class="mapa-popup-placa">${v.autobus_placas || ''}</span>
        </div>
        <div class="mapa-popup-ruta">
          <span class="mapa-popup-orig">${v.origen_ciudad}</span>
          <span class="mapa-popup-flecha">→</span>
          <span class="mapa-popup-dest">${v.destino_ciudad}</span>
        </div>
        <div class="mapa-popup-sep"></div>
        <div class="mapa-popup-fila">
          <span class="mapa-popup-key">Conductor</span>
          <span>${v.conductor || '—'}</span>
        </div>
        <div class="mapa-popup-fila">
          <span class="mapa-popup-key">Salida</span>
          <span>${fmtHora(v.fecHoraSalida)}</span>
        </div>
        <div class="mapa-popup-fila">
          <span class="mapa-popup-key">Llegada est.</span>
          <span>${fmtHora(v.fecHoraEntrada)}</span>
        </div>
        <div class="mapa-popup-fila">
          <span class="mapa-popup-key">Duración</span>
          <span>${v.duracion_ruta || '—'}</span>
        </div>
        <div class="mapa-popup-progress-wrap">
          <div class="mapa-popup-progress-bar">
            <div class="mapa-popup-progress-fill" style="width:${pct}%"></div>
          </div>
          <span class="mapa-popup-pct">${pct}% del trayecto</span>
        </div>
        <div class="mapa-popup-terminals">
          🏢 ${v.origen_terminal || '—'} → ${v.destino_terminal || '—'}
        </div>
      </div>`)
    .openOn(mapaLeaflet);
}

/* ════════════════════════════════════════════════════════
   LOOP DE ANIMACIÓN
════════════════════════════════════════════════════════ */
function animLoop() {
  const PASO = 0.00005; // avance por frame en simulación

  Object.values(mapaViajes).forEach(m => {
    // Progreso real basado en tiempo
    const progresoReal = calcularProgreso(
      m.datos.fecHoraSalida,
      m.datos.fecHoraEntrada,
      m.datos.duracion_ruta
    );

    // Suavizar: avanzar animación hacia el progreso real
    if (m.progreso < progresoReal) {
      m.progreso = Math.min(m.progreso + PASO, progresoReal);
    }

    const pos = interpolar(m.orig, m.dest, m.progreso);
    m.marker.setLatLng(pos);
  });

  mapaAnimId = requestAnimationFrame(animLoop);
}

/* ════════════════════════════════════════════════════════
   UTILIDADES
════════════════════════════════════════════════════════ */
function interpolar([lat1, lng1], [lat2, lng2], t) {
  const tt = Math.max(0, Math.min(1, t));
  return [lat1 + (lat2 - lat1) * tt, lng1 + (lng2 - lng1) * tt];
}

function calcularProgreso(salida, entrada, duracion) {
  const ahora  = Date.now();
  const inicio = new Date(salida).getTime();
  const fin    = new Date(entrada).getTime();

  // Si fecHoraEntrada no es confiable, usar duracion parseada
  const finReal = (fin > inicio) ? fin : inicio + parseDuracion(duracion);

  if (ahora <= inicio) return 0;
  if (ahora >= finReal) return 0.98;
  return (ahora - inicio) / (finReal - inicio);
}

function fmtHora(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return isNaN(d) ? iso : d.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' });
}

function actualizarContador(n) {
  const el = document.getElementById('mapa-count');
  if (el) el.textContent = `${n} viaje${n !== 1 ? 's' : ''} en ruta`;
}

function iconoBus(v) {
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="36" height="36" viewBox="0 0 36 36">
      <circle cx="18" cy="18" r="16" fill="#1181c3" fill-opacity="0.15"
              stroke="#1181c3" stroke-width="1.8"/>
      <text x="18" y="24" text-anchor="middle"
            font-size="17" font-family="sans-serif">🚌</text>
    </svg>`;
  return L.divIcon({
    html:        svg,
    className:   '',
    iconSize:    [36, 36],
    iconAnchor:  [18, 18],
    popupAnchor: [0, -20],
  });
}

/* ════════════════════════════════════════════════════════
   SERVICE WORKER
════════════════════════════════════════════════════════ */
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register('/static/dashboard/sw-mapa.js')
      .then(r  => console.log('[SW] OK:', r.scope))
      .catch(e => console.warn('[SW] Error:', e));
  });
}