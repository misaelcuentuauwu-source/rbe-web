/* ════════════════════════════════════════════════════════
   MAPA — Lógica principal
   django/static/dashboard/mapa.js
════════════════════════════════════════════════════════ */

/* ── Coordenadas centríficas de ciudades de Baja California ── */
const BC_CIUDADES = {
  'Tijuana':        [32.5149, -117.0382],
  'Mexicali':       [32.6245, -115.4523],
  'Ensenada':       [31.8667, -116.5960],
  'Tecate':         [32.5735, -116.6270],
  'Rosarito':       [32.3732, -117.0381],
  'San Quintín':    [30.5380, -115.9500],
  'El Rosario':     [30.0600, -115.7200],
  'Guerrero Negro': [27.9757, -114.0422],
  'San Felipe':     [31.0167, -114.8333],
  'Loreto':         [26.0122, -111.3456],
  'Maneadero':      [31.7167, -116.5833],
  'Valle de Guadalupe': [32.0370, -116.6420],
  'La Paz':         [24.1426, -110.3128],
  'Cabo San Lucas': [22.8905, -109.9167],
  'San José del Cabo': [23.0633, -109.6891],
};

/* ── Fallback si la ciudad no está en el diccionario ── */
function getCoordsForCity(nombre) {
  if (!nombre) return null;
  // Búsqueda exacta
  if (BC_CIUDADES[nombre]) return BC_CIUDADES[nombre];
  // Búsqueda parcial (ignora mayúsculas)
  const key = Object.keys(BC_CIUDADES).find(k =>
    k.toLowerCase().includes(nombre.toLowerCase()) ||
    nombre.toLowerCase().includes(k.toLowerCase())
  );
  return key ? BC_CIUDADES[key] : null;
}

/* ══════════════════════════════════════════════
   ESTADO GLOBAL DEL MAPA
══════════════════════════════════════════════ */
let mapaLeaflet     = null;   // instancia Leaflet
let mapaMarkers     = {};     // { viaje_numero: { marker, progreso, ruta } }
let mapaViajes      = [];     // última copia de rows de la API
let mapaAnimFrame   = null;   // requestAnimationFrame handle
let mapaInitialized = false;

/* ══════════════════════════════════════════════
   INICIALIZAR MAPA
══════════════════════════════════════════════ */
function inicializarMapa() {
  if (mapaInitialized) return;
  mapaInitialized = true;

  // Centrado en Baja California
  mapaLeaflet = L.map('mapa-leaflet', {
    center: [30.5, -115.5],
    zoom: 7,
    zoomControl: true,
  });

  // Tiles OpenStreetMap
  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    maxZoom: 18,
  }).addTo(mapaLeaflet);

  // Cargar viajes y arrancar animación
  cargarViajesMapa();

  // Actualizar cada 60 segundos
  setInterval(cargarViajesMapa, 60_000);

  // Detectar online/offline
  window.addEventListener('offline', () => {
    document.getElementById('mapa-offline-banner')?.classList.add('visible');
  });
  window.addEventListener('online', () => {
    document.getElementById('mapa-offline-banner')?.classList.remove('visible');
    cargarViajesMapa();
  });
}

/* ══════════════════════════════════════════════
   FETCH DE VIAJES
══════════════════════════════════════════════ */
async function cargarViajesMapa() {
  const btnRefresh = document.getElementById('mapa-btn-refresh');
  if (btnRefresh) btnRefresh.classList.add('girando');

  try {
    const res  = await fetch('/api/salidas/');
    const data = await res.json();
    mapaViajes = data.rows || [];
    actualizarMarcadores(mapaViajes);
    actualizarContadorMapa(mapaViajes.length);
  } catch (e) {
    console.warn('[Mapa] Error al cargar viajes:', e);
  } finally {
    if (btnRefresh) btnRefresh.classList.remove('girando');
  }
}

/* ══════════════════════════════════════════════
   MARCADORES Y RUTAS
══════════════════════════════════════════════ */
function actualizarMarcadores(viajes) {
  const numerosActivos = new Set();

  viajes.forEach(v => {
    const orig = getCoordsForCity(v.origen_ciudad);
    const dest = getCoordsForCity(v.destino_ciudad);
    if (!orig || !dest) return;

    const id = v.numero;
    numerosActivos.add(id);

    // Calcular progreso 0→1 según tiempo
    const progreso = calcularProgreso(v.fecHoraSalida, v.fecHoraEntrada);

    if (mapaMarkers[id]) {
      // Actualizar destino de animación
      mapaMarkers[id].orig     = orig;
      mapaMarkers[id].dest     = dest;
      mapaMarkers[id].progreso = progreso;
      mapaMarkers[id].viaje    = v;
    } else {
      // Crear marcador nuevo
      const pos    = interpolarPos(orig, dest, progreso);
      const icon   = crearIconoBus(v);
      const marker = L.marker(pos, { icon }).addTo(mapaLeaflet);
      marker.bindPopup(crearPopupHTML(v, progreso));

      // Línea de ruta (semitransparente)
      const linea = L.polyline([orig, dest], {
        color: '#1181c3',
        weight: 2,
        opacity: 0.25,
        dashArray: '6 6',
      }).addTo(mapaLeaflet);

      mapaMarkers[id] = { marker, linea, orig, dest, progreso, viaje: v };
    }
  });

  // Eliminar marcadores de viajes que ya no están en la respuesta
  Object.keys(mapaMarkers).forEach(id => {
    if (!numerosActivos.has(Number(id))) {
      mapaMarkers[id].marker.remove();
      mapaMarkers[id].linea.remove();
      delete mapaMarkers[id];
    }
  });

  // Arrancar loop de animación si no está corriendo
  if (!mapaAnimFrame) animarBuses();
}

/* ══════════════════════════════════════════════
   LOOP DE ANIMACIÓN
══════════════════════════════════════════════ */
function animarBuses() {
  const VELOCIDAD = 0.00003; // avance por frame (ajusta a gusto)

  Object.values(mapaMarkers).forEach(m => {
    // Solo animar viajes "en ruta"
    const estado = (m.viaje.estado || '').toLowerCase();
    if (!estado.includes('ruta') && !estado.includes('viaje')) return;

    m.progreso = Math.min(m.progreso + VELOCIDAD, 0.99);
    const pos  = interpolarPos(m.orig, m.dest, m.progreso);
    m.marker.setLatLng(pos);

    // Actualizar popup si está abierto
    if (m.marker.isPopupOpen()) {
      m.marker.setPopupContent(crearPopupHTML(m.viaje, m.progreso));
    }
  });

  mapaAnimFrame = requestAnimationFrame(animarBuses);
}

/* ══════════════════════════════════════════════
   UTILIDADES
══════════════════════════════════════════════ */

/** Interpolación lineal entre dos coordenadas */
function interpolarPos([lat1, lng1], [lat2, lng2], t) {
  return [
    lat1 + (lat2 - lat1) * t,
    lng1 + (lng2 - lng1) * t,
  ];
}

/** Progreso 0→1 basado en fecHoraSalida / fecHoraEntrada */
function calcularProgreso(salida, entrada) {
  if (!salida || !entrada) return 0;
  const ahora  = Date.now();
  const inicio = new Date(salida).getTime();
  const fin    = new Date(entrada).getTime();
  if (ahora <= inicio) return 0;
  if (ahora >= fin)    return 0.99;
  return (ahora - inicio) / (fin - inicio);
}

/** Color del marcador según estado */
function colorPorEstado(estado) {
  const e = (estado || '').toLowerCase();
  if (e.includes('ruta') || e.includes('viaje')) return '#1181c3';
  if (e.includes('disp'))                         return '#22c55e';
  return '#94a3b8';
}

/** Icono SVG de autobús como DivIcon de Leaflet */
function crearIconoBus(viaje) {
  const color = colorPorEstado(viaje.estado);
  const svg = `
    <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32">
      <circle cx="16" cy="16" r="14" fill="${color}" fill-opacity=".18" stroke="${color}" stroke-width="1.5"/>
      <text x="16" y="21" text-anchor="middle" font-size="15" font-family="sans-serif">🚌</text>
    </svg>`;
  return L.divIcon({
    html: svg,
    className: '',
    iconSize:   [32, 32],
    iconAnchor: [16, 16],
    popupAnchor:[0, -18],
  });
}

/** HTML del popup */
function crearPopupHTML(v, progreso) {
  const pct    = Math.round(progreso * 100);
  const estado = v.estado || 'Desconocido';
  const cls    = claseEstado(estado);
  const fecha  = v.fecHoraSalida ? v.fecHoraSalida.substring(0, 10) : '';
  return `
    <div class="mapa-popup">
      <div class="mapa-popup-head">
        <div class="mapa-popup-titulo">🚌 Bus #${v.autobus_num || '—'}</div>
        <span class="mapa-popup-codigo">#${v.numero || '—'}</span>
      </div>
      <div class="mapa-popup-ruta">${v.origen_ciudad} <span class="mapa-popup-flecha">→</span> ${v.destino_ciudad}</div>
      <div class="mapa-popup-divider"></div>
      <div class="mapa-popup-fila"><span class="mapa-popup-key">Conductor</span>${v.conductor || '—'}</div>
      <div class="mapa-popup-fila"><span class="mapa-popup-key">Placas</span>${v.autobus_placas || '—'}</div>
      <div class="mapa-popup-fila"><span class="mapa-popup-key">Salida</span>${formatHora(v.fecHoraSalida)}</div>
      <div class="mapa-popup-fila"><span class="mapa-popup-key">Llegada est.</span>${formatHora(v.fecHoraEntrada)}</div>
      <div class="mapa-popup-fila"><span class="mapa-popup-key">Duración</span>${calcularDuracion(v.fecHoraSalida, v.fecHoraEntrada)}</div>
      <div class="mapa-popup-progreso-wrap">
        <div class="mapa-popup-progreso-bar"><div class="mapa-popup-progreso-fill" style="width:${pct}%"></div></div>
        <span class="mapa-popup-progreso-pct">${pct}% del trayecto</span>
      </div>
      <div class="mapa-popup-footer">
        <span class="mapa-popup-estado ${cls}">${estado}</span>
        <button class="mapa-popup-btn-ver" onclick="irAHistorialViaje(${v.numero || 0}, '${fecha}')">🔍 Ver viaje</button>
      </div>
    </div>`;
}

function claseEstado(estado) {
  const e = (estado || '').toLowerCase();
  if (e.includes('ruta') || e.includes('viaje')) return 'en-ruta';
  if (e.includes('disp'))                         return 'disponible';
  return 'otro';
}

function formatHora(iso) {
  if (!iso) return '—';
  const d = new Date(iso);
  return isNaN(d) ? iso : d.toLocaleTimeString('es-MX', { hour:'2-digit', minute:'2-digit' });
}

function calcularDuracion(salida, entrada) {
  if (!salida || !entrada) return '—';
  const ms = new Date(entrada).getTime() - new Date(salida).getTime();
  if (isNaN(ms) || ms <= 0) return '—';
  const h = Math.floor(ms / 3600000);
  const m = Math.floor((ms % 3600000) / 60000);
  return h > 0 ? `${h}h ${m}m` : `${m}m`;
}

function actualizarContadorMapa(n) {
  const el = document.getElementById('mapa-count');
  if (el) el.textContent = `${n} viaje${n !== 1 ? 's' : ''} activo${n !== 1 ? 's' : ''}`;
}

/* ══════════════════════════════════════════════
   SERVICE WORKER — registro
══════════════════════════════════════════════ */
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/static/dashboard/sw-mapa.js')
      .then(reg => console.log('[SW] Registrado:', reg.scope))
      .catch(err => console.warn('[SW] Error:', err));
  });
}