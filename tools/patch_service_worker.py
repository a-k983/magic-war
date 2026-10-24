"""Replace Godot's cache-first service worker with a network-first one.

Usage:  python tools/patch_service_worker.py [build/web]

Godot's generated index.service.worker.js serves the game from its cache
first, so a home-screen install keeps running an old build. This script
rewrites it to:
  - always fetch from the network first (revalidating past the HTTP cache),
    and fall back to the cache only when offline;
  - activate a new version immediately (skipWaiting + clients.claim).

It keeps the values Godot generated for this export (CACHE_VERSION, the file
lists, the offline page, the COOP/COEP setting), so the worker file still
changes on every export and browsers pick the update up. Safe to run twice:
an already-patched file is left alone.
"""

import re
import sys
from pathlib import Path

MARKER = "// PATCHED: network-first (tools/patch_service_worker.py)"

TEMPLATE = MARKER + r"""
// Network-first service worker for the Godot Web export.
// Online: every request goes to the network (revalidating past the HTTP
// cache) and the fresh copy is stored for offline use. Offline: the last
// stored copy is served. A new export changes CACHE_VERSION, which makes the
// browser install this worker again; it takes over immediately.
const CACHE_VERSION = __CACHE_VERSION__;
const CACHE_PREFIX = __CACHE_PREFIX__;
const CACHE_NAME = CACHE_PREFIX + CACHE_VERSION;
const OFFLINE_URL = __OFFLINE_URL__;
const ENSURE_CROSSORIGIN_ISOLATION_HEADERS = __ENSURE_COI__;
const CACHED_FILES = __CACHED_FILES__;
const CACHEABLE_FILES = __CACHEABLE_FILES__;
const FULL_CACHE = CACHED_FILES.concat(CACHEABLE_FILES);

self.addEventListener('install', (event) => {
	// Precache the small files (skipping the HTTP cache), then take over
	// right away instead of waiting for every open copy of the game to close.
	event.waitUntil(
		caches.open(CACHE_NAME)
			.then((cache) => cache.addAll(CACHED_FILES.map((f) => new Request(f, { cache: 'reload' }))))
			.then(() => self.skipWaiting())
	);
});

self.addEventListener('activate', (event) => {
	// Drop caches from older builds, then control already-open pages.
	event.waitUntil(
		caches.keys()
			.then((keys) => Promise.all(keys
				.filter((key) => key.startsWith(CACHE_PREFIX) && key !== CACHE_NAME)
				.map((key) => caches.delete(key))))
			.then(() => self.clients.claim())
	);
});

function ensureCrossOriginIsolationHeaders(response) {
	if (!ENSURE_CROSSORIGIN_ISOLATION_HEADERS || response.type === 'opaque') {
		return response;
	}
	if (response.headers.get('Cross-Origin-Embedder-Policy') === 'require-corp'
		&& response.headers.get('Cross-Origin-Opener-Policy') === 'same-origin') {
		return response;
	}
	const headers = new Headers(response.headers);
	headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
	headers.set('Cross-Origin-Opener-Policy', 'same-origin');
	return new Response(response.body, {
		status: response.status,
		statusText: response.statusText,
		headers: headers,
	});
}

// Path of a request relative to this worker's folder, e.g. "index.pck".
function localName(url) {
	const scope = self.registration.scope;
	const clean = url.split('#')[0].split('?')[0];
	return clean.startsWith(scope) ? clean.slice(scope.length) : null;
}

async function networkFirst(request, cacheKey) {
	const cache = await caches.open(CACHE_NAME);
	try {
		// 'no-cache' = always ask the server, which answers 304 (no download)
		// when the file hasn't changed. Beats GitHub Pages' 10-minute cache.
		// (Navigations are re-fetched by URL: a navigate-mode request can't
		// be sent again with changed options.)
		const response = request.mode === 'navigate'
			? await fetch(request.url, { cache: 'no-cache', credentials: 'same-origin' })
			: await fetch(request, { cache: 'no-cache' });
		if (response.ok && cacheKey) {
			cache.put(cacheKey, response.clone());
		}
		return ensureCrossOriginIsolationHeaders(response);
	} catch (e) {
		const cached = cacheKey ? await cache.match(cacheKey) : undefined;
		if (cached) {
			return ensureCrossOriginIsolationHeaders(cached);
		}
		if (request.mode === 'navigate') {
			const offline = await cache.match(OFFLINE_URL);
			if (offline) {
				return offline;
			}
		}
		throw e;
	}
}

self.addEventListener('fetch', (event) => {
	const request = event.request;
	if (request.method !== 'GET') {
		return;
	}
	const name = localName(request.url);
	if (name === null) {
		return; // Not ours (other origin): let the browser handle it.
	}
	let cacheKey = null;
	if (request.mode === 'navigate' && (name === '' || name === CACHED_FILES[0])) {
		cacheKey = CACHED_FILES[0]; // The game page, however it was opened
	} else if (FULL_CACHE.includes(name)) {
		cacheKey = name;
	}
	event.respondWith(networkFirst(request, cacheKey));
});

self.addEventListener('message', (event) => {
	// Kept for compatibility with Godot's page script.
	if (event.origin !== self.origin) {
		return;
	}
	const msg = event.data || '';
	if (msg === 'claim') {
		self.skipWaiting().then(() => self.clients.claim());
	} else if (msg === 'clear') {
		caches.delete(CACHE_NAME);
	} else if (msg === 'update') {
		self.skipWaiting()
			.then(() => self.clients.claim())
			.then(() => self.clients.matchAll())
			.then((all) => all.forEach((c) => c.navigate(c.url)));
	}
});
"""

# Constant name -> placeholder in TEMPLATE. Values are copied verbatim (they
# are already JavaScript literals in Godot's file).
CONSTANTS = {
	"CACHE_VERSION": "__CACHE_VERSION__",
	"CACHE_PREFIX": "__CACHE_PREFIX__",
	"OFFLINE_URL": "__OFFLINE_URL__",
	"ENSURE_CROSSORIGIN_ISOLATION_HEADERS": "__ENSURE_COI__",
	"CACHED_FILES": "__CACHED_FILES__",
	"CACHEABLE_FILES": "__CACHEABLE_FILES__",
}


def main() -> int:
	web_dir = Path(sys.argv[1] if len(sys.argv) > 1 else "build/web")
	workers = sorted(web_dir.glob("*.service.worker.js"))
	if not workers:
		print(f"No *.service.worker.js in {web_dir} - is PWA enabled in the Web preset?")
		return 1
	for sw in workers:
		source = sw.read_text(encoding="utf-8")
		if source.startswith(MARKER):
			print(f"{sw}: already patched")
			continue
		out = TEMPLATE
		for name, placeholder in CONSTANTS.items():
			match = re.search(rf"^const {name} = (.+?);\s*$", source, re.MULTILINE)
			if not match:
				# Godot changed its worker format: fail loudly rather than
				# publish a broken worker.
				print(f"{sw}: could not find 'const {name} = ...;' - not patched")
				return 1
			out = out.replace(placeholder, match.group(1))
		sw.write_text(out, encoding="utf-8", newline="\n")
		print(f"{sw}: patched to network-first")
	return 0


if __name__ == "__main__":
	sys.exit(main())
