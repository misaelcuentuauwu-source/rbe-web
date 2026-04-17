/* ════════════════════════════════════════════════════════
   MAPA — Lógica principal
   django/static/dashboard/mapa.js
════════════════════════════════════════════════════════ */

const BC_CIUDADES = {
  'Tijuana':     [32.5149, -117.0382],
  'Mexicali':    [32.6245, -115.4523],
  'Ensenada':    [31.8667, -116.5960],
  'Tecate':      [32.5735, -116.6270],
  'Rosarito':    [32.3732, -117.0381],
  'San Quintín': [30.5380, -115.9500],
  'San Quintin': [30.5380, -115.9500],
  'San Felipe':  [31.0167, -114.8333],
};

function getCoordsForCity(nombre) {
  if (!nombre) return null;
  if (BC_CIUDADES[nombre]) return BC_CIUDADES[nombre];
  const key = Object.keys(BC_CIUDADES).find(k =>
    k.toLowerCase().includes(nombre.toLowerCase()) ||
    nombre.toLowerCase().includes(k.toLowerCase())
  );
  return key ? BC_CIUDADES[key] : null;
}

let mapaLeaflet     = null;
let mapaMarkers     = {};
let mapaViajes      = [];
let mapaAnimFrame   = null;
let mapaInitialized = false;

function inicializarMapa() {
  if (mapaInitialized) return;
  mapaInitialized = true;

  mapaLeaflet = L.map('mapa-leaflet', {
    center: [30.5, -115.5],
    zoom: 7,
    zoomControl: true,
  });

  L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
    attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
    maxZoom: 18,
  }).addTo(mapaLeaflet);

  cargarViajesMapa();
  setInterval(cargarViajesMapa, 60_000);

  window.addEventListener('offline', () => {
    document.getElementById('mapa-offline-banner')?.classList.add('visible');
  });
  window.addEventListener('online', () => {
    document.getElementById('mapa-offline-banner')?.classList.remove('visible');
    cargarViajesMapa();
  });
}

async function cargarViajesMapa() {
  const btnRefresh = document.getElementById('mapa-btn-refresh');
  if (btnRefresh) btnRefresh.classList.add('girando');

  try {
    const res  = await fetch('/api/salidas/?solo_en_ruta=1');
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

function coloresPorDireccion(origenCiudad, destinoCiudad) {
  const esDeTijuana = (origenCiudad || '').toLowerCase().includes('tijuana');
  
  if (esDeTijuana) {
    return {
      recorrida: '#00aaff',  // azul eléctrico
      sombra:    '#001a66',  // azul oscuro
    };
  } else {
    return {
      recorrida: '#22c55e',  // verde
      sombra:    '#14532d',  // verde oscuro
    };
  }
}


function actualizarMarcadores(viajes) {
  const numerosActivos = new Set();

  viajes.forEach(v => {
    const estado = (v.estado || '').toLowerCase();
    if (!estado.includes('ruta')) return;

    const orig = getCoordsForCity(v.origen_ciudad);
    const dest = getCoordsForCity(v.destino_ciudad);
    if (!orig || !dest) return;

    const id = v.numero;
    numerosActivos.add(id);

    const progreso = calcularProgreso(v.fecHoraSalida, v.fecHoraEntrada);

if (mapaMarkers[id]) {
      mapaMarkers[id].orig  = orig;
      mapaMarkers[id].dest  = dest;
      mapaMarkers[id].viaje = v;
      // Solo avanza, nunca retrocede
      const progresoReal = calcularProgreso(v.fecHoraSalida, v.fecHoraEntrada);
      if (progresoReal > mapaMarkers[id].progreso) {
        mapaMarkers[id].progreso = progresoReal;
      }
    } else {
      const pos    = interpolarPos(orig, dest, progreso);
      const icon   = crearIconoBus(v);
      const marker = L.marker(pos, { icon }).addTo(mapaLeaflet);
      marker.bindPopup(crearPopupHTML(v, progreso));

      const lineaPendiente = L.polyline([orig, dest], {
        color: '#b0c4de',
        weight: 4,
        opacity: 0.7,
        dashArray: '10 8',
      }).addTo(mapaLeaflet);

      const posActual = interpolarPos(orig, dest, progreso);

      const colores   = coloresPorDireccion(v.origen_ciudad, v.destino_ciudad);
      const velocidad = calcularVelocidad(v.fecHoraSalida, v.fecHoraEntrada);


      const lineaRecorrida = L.polyline([orig, posActual], {
        color: colores.recorrida,
        weight: 8,
        opacity: 1,
      }).addTo(mapaLeaflet);

      mapaMarkers[id] = { marker, linea: lineaPendiente, lineaRecorrida, colores, orig, dest, progreso, velocidad, viaje: v };
    }
  });

  // Eliminar marcadores que ya no están activos
  Object.keys(mapaMarkers).forEach(id => {
    if (!numerosActivos.has(Number(id))) {
      mapaMarkers[id].marker.remove();
      mapaMarkers[id].linea.remove();
      mapaMarkers[id].lineaRecorrida?.remove();
      delete mapaMarkers[id];
    }
  });

  if (!mapaAnimFrame) animarBuses();
}

function animarBuses() {
  const VELOCIDAD = 0.00003;

  Object.values(mapaMarkers).forEach(m => {
    const estado = (m.viaje.estado || '').toLowerCase();
    if (!estado.includes('ruta') && !estado.includes('viaje')) return;

    m.progreso = Math.min(m.progreso + m.velocidad, 0.99);
    const pos  = interpolarPos(m.orig, m.dest, m.progreso);
    m.marker.setLatLng(pos);

    if (m.lineaRecorrida) m.lineaRecorrida.setLatLngs([m.orig, pos]);

    if (m.marker.isPopupOpen()) {
      m.marker.setPopupContent(crearPopupHTML(m.viaje, m.progreso));
    }
  });

  mapaAnimFrame = requestAnimationFrame(animarBuses);
}

function interpolarPos([lat1, lng1], [lat2, lng2], t) {
  return [
    lat1 + (lat2 - lat1) * t,
    lng1 + (lng2 - lng1) * t,
  ];
}

function calcularProgreso(salida, entrada) {
  if (!salida || !entrada) return 0;
  const ahora  = Date.now();
  const inicio = new Date(salida).getTime();
  const fin    = new Date(entrada).getTime();
  if (ahora <= inicio) return 0;
  if (ahora >= fin)    return 0.99;
  return (ahora - inicio) / (fin - inicio);
}

function colorPorEstado(estado) {
  const e = (estado || '').toLowerCase();
  if (e.includes('ruta') || e.includes('viaje')) return '#1181c3';
  if (e.includes('disp'))                         return '#22c55e';
  return '#94a3b8';
}

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

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('/static/dashboard/sw-mapa.js')
      .then(reg => console.log('[SW] Registrado:', reg.scope))
      .catch(err => console.warn('[SW] Error:', err));
  });
}

function calcularVelocidad(salida, entrada) {
  if (!salida || !entrada) return 0.00003; // fallback
  const duracionMs = new Date(entrada) - new Date(salida);
  // progreso va de 0 a 1 en duracionMs milisegundos
  // animarBuses corre ~60fps → 60 frames/seg
  return 1 / (duracionMs / 1000 * 60);
}