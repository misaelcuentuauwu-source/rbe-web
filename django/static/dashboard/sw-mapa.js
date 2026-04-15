/* ════════════════════════════════════════════════════
   SERVICE WORKER — Caché de tiles OSM
   django/static/dashboard/sw-mapa.js
════════════════════════════════════════════════════ */

const CACHE_TILES = 'osm-tiles-v1';
const CACHE_APP   = 'rbe-app-v1';

/* Archivos del app que se cachean en instalación */
const APP_SHELL = [
  '/static/dashboard/mapa.css',
  '/static/dashboard/mapa.js',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
];

/* ── Instalación ── */
self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE_APP)
      .then(cache => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

/* ── Activación: limpiar caches viejos ── */
self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(k => k !== CACHE_TILES && k !== CACHE_APP)
          .map(k => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

/* ── Fetch: estrategia por tipo de recurso ── */
self.addEventListener('fetch', e => {
  const url = e.request.url;

  /* Tiles de OSM → Cache first, luego red */
  if (url.includes('tile.openstreetmap.org')) {
    e.respondWith(
      caches.open(CACHE_TILES).then(async cache => {
        const cached = await cache.match(e.request);
        if (cached) return cached;
        try {
          const resp = await fetch(e.request);
          if (resp.ok) cache.put(e.request, resp.clone());
          return resp;
        } catch {
          return new Response('', { status: 503 });
        }
      })
    );
    return;
  }

  /* App shell → Cache first */
  if (APP_SHELL.some(a => url.includes(a))) {
    e.respondWith(
      caches.match(e.request).then(cached => cached || fetch(e.request))
    );
    return;
  }

  /* API /api/salidas/ → Network first (datos frescos) */
  if (url.includes('/api/salidas/')) {
    e.respondWith(
      fetch(e.request).catch(() => caches.match(e.request))
    );
    return;
  }

  /* Todo lo demás → red normal */
});