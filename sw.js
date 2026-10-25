/* Service Worker de la PWA "Simulador de Trenes"
   ------------------------------------------------------------------
   Registrado desde /trenes/sw.js, su ámbito queda acotado a /trenes/
   y NO interfiere con el service worker del portal principal
   (https://tecdea.github.io/). Solo atiende peticiones dentro de su
   propio ámbito u orígenes externos (CDNs); nunca responde por
   recursos del portal raíz.
   ------------------------------------------------------------------ */
'use strict';

const APP_VERSION = '1.1.5';
const CACHE_NAME = `trenes-pwa-${APP_VERSION}`;

/* Precachea el esqueleto de la app (rutas relativas a /trenes/). */
const PRECACHE = [
  './',
  './index.html',
  './manifest.json',
  './icons/favicon.svg',
  './icons/favicon-32.png',
  './icons/favicon-16.png',
  './icons/apple-touch-icon.png',
  './icons/icon-192.png',
  './icons/icon-512.png',
  './icons/maskable-512.png'
];

/* Instalación: precacheo del esqueleto. */
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => cache.addAll(PRECACHE))
      .then(() => self.skipWaiting())
  );
});

/* Activación: limpia cachés antiguas de ESTA app (prefijo trenes-pwa-)
   y toma el control inmediato de las páginas de su ámbito. */
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(
        keys
          .filter((k) => k.startsWith('trenes-pwa-') && k !== CACHE_NAME)
          .map((k) => caches.delete(k))
      ))
      .then(() => self.clients.claim())
  );
});

/* Mensajes: SKIP_WAITING (actualización) y GET_VERSION (chip/depuración). */
self.addEventListener('message', (event) => {
  if (event.data === 'SKIP_WAITING') {
    self.skipWaiting();
  } else if (event.data === 'GET_VERSION' && event.ports && event.ports[0]) {
    event.ports[0].postMessage({ type: 'APP_VERSION', version: APP_VERSION });
  }
});

/* Fetch:
   - Solo GET.
   - Peticiones del MISMO origen: solo si están dentro de /trenes/
     (defensa extra para no interceptar nada del portal raíz).
   - Peticiones de ORIGEN EXTERNO (CDNs de Tailwind, Lucide, fuentes):
     estrategia stale-while-revalidate para permitir uso sin conexión.
   - Navegaciones: network-first con fallback a la caché (offline). */
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET') return;

  const url = new URL(req.url);
  const scopeUrl = new URL(self.registration.scope);
  const sameOrigin = url.origin === self.location.origin;
  const inScope = sameOrigin && url.pathname.startsWith(scopeUrl.pathname);

  if (!inScope && !sameOrigin) return; // no toca peticiones ajenas

  /* Navegación (recarga / arranque de la PWA): red primero, caché después. */
  if (req.mode === 'navigate') {
    event.respondWith(
      fetch(req)
        .then((res) => {
          const copy = res.clone();
          caches.open(CACHE_NAME).then((c) => c.put('./index.html', copy));
          return res;
        })
        .catch(() => caches.match('./index.html'))
    );
    return;
  }

  /* Resto: stale-while-revalidate (respuesta rápida desde caché,
     revalidación en segundo plano). */
  event.respondWith(
    caches.open(CACHE_NAME).then(async (cache) => {
      const cached = await cache.match(req);
      const network = fetch(req)
        .then((res) => {
          // Cachear solo respuestas válidas (y opacas de CDN).
          if (res && (res.ok || res.type === 'opaque')) {
            cache.put(req, res.clone());
          }
          return res;
        })
        .catch(() => cached);
      return cached || network;
    })
  );
});
