/* ════════════════════════════════════════════════════
   SERVICE WORKER — Caché de tiles OSM + datos API
   django/static/dashboard/sw-mapa.js
════════════════════════════════════════════════════ */

const CACHE_TILES   = 'osm-tiles-v2';
const CACHE_APP     = 'rbe-app-v2';
const CACHE_API     = 'rbe-api-v2';

const APP_SHELL = [
  '/static/dashboard/mapa.css',
  '/static/dashboard/mapa.js',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.css',
  'https://unpkg.com/leaflet@1.9.4/dist/leaflet.js',
];

self.addEventListener('install', e => {
  e.waitUntil(
    caches.open(CACHE_APP)
      .then(cache => cache.addAll(APP_SHELL))
      .then(() => self.skipWaiting())
  );
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys =>
      Promise.all(
        keys
          .filter(k => ![CACHE_TILES, CACHE_APP, CACHE_API].includes(k))
          .map(k => caches.delete(k))
      )
    ).then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', e => {
  const url = e.request.url;

  /* Tiles OSM → Cache first, luego red */
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
  if (APP_SHELL.some(a => url.includes(a.replace(/^https?:\/\/[^/]+/, '')))) {
    e.respondWith(
      caches.match(e.request).then(cached => cached || fetch(e.request))
    );
    return;
  }

  /* API /api/salidas/ → Network first, caché como fallback offline */
  if (url.includes('/api/salidas/')) {
    e.respondWith(
      caches.open(CACHE_API).then(async cache => {
        try {
          const resp = await fetch(e.request);
          if (resp.ok) {
            // Guardar respuesta fresca en caché (clonar antes de usar)
            cache.put(e.request, resp.clone());
          }
          return resp;
        } catch {
          // Sin red: devolver el caché
          const cached = await cache.match(e.request);
          return cached || new Response(
            JSON.stringify({ rows: [], offline: true }),
            { headers: { 'Content-Type': 'application/json' } }
          );
        }
      })
    );
    return;
  }

  /* Todo lo demás → red normal */
});