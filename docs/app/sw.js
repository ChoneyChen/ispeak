const CACHE='ispeak-general-v4';
const URLS=['./','./index.html','./app.css','./app.js','./engine.mjs','./manifest.webmanifest','../assets/general-curriculum.json','../assets/icon-192.png','../assets/icon-512.png','../assets/favicon.svg'];
const APP_BASE=new URL('./',self.location.href).href;
const ALLOWED=new Set(URLS.map(path=>new URL(path,self.location.href).href));
self.addEventListener('install',e=>e.waitUntil(caches.open(CACHE).then(cache=>cache.addAll(URLS)).then(()=>self.skipWaiting())));
self.addEventListener('activate',e=>e.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k.startsWith('ispeak-general-')&&k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim()).then(()=>self.clients.matchAll().then(clients=>clients.forEach(c=>c.postMessage('CACHE_READY'))))));
self.addEventListener('message',e=>{if(e.data==='CHECK_CACHE')e.source?.postMessage('CACHE_READY');});
self.addEventListener('fetch',e=>{const url=new URL(e.request.url);if(e.request.method!=='GET'||url.origin!==self.location.origin||!url.href.startsWith(APP_BASE)&&!ALLOWED.has(url.href))return;e.respondWith(fetch(e.request).then(response=>{if(response.ok){const copy=response.clone();e.waitUntil(caches.open(CACHE).then(cache=>cache.put(e.request,copy)));}return response;}).catch(async()=>{const hit=await caches.match(e.request);if(hit)return hit;if(e.request.mode==='navigate')return caches.match(new URL('./index.html',self.location.href).href);throw Error('This resource is not cached.');}));});
