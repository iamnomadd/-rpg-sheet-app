const VERSION='1.3.35+135';
const CACHE='rpg-sheet-'+VERSION;
const CORE=['/','/index.html','/manifest.json','/icons/Icon-192.png','/icons/Icon-512.png','/icons/apple-touch-icon.png','/icons/apple-touch-icon-167.png'];

self.addEventListener('install',event=>{
  self.skipWaiting();
  event.waitUntil(caches.open(CACHE).then(c=>c.addAll(CORE)));
});

self.addEventListener('activate',event=>{
  event.waitUntil((async()=>{
    const keys=await caches.keys();
    await Promise.all(keys.filter(k=>k.startsWith('rpg-sheet-')&&k!==CACHE).map(k=>caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch',event=>{
  if(event.request.method!=='GET')return;
  const url=new URL(event.request.url);
  if(url.origin!==self.location.origin)return;

  // HTML/navigation: network first, cached shell only when offline.
  if(event.request.mode==='navigate'){
    event.respondWith(
      fetch(event.request,{cache:'no-store'}).then(response=>{
        if(response&&response.ok){
          const copy=response.clone();
          caches.open(CACHE).then(c=>c.put('/index.html',copy));
        }
        return response;
      }).catch(()=>caches.match('/index.html'))
    );
    return;
  }

  // Static Flutter assets: cache first for substantially faster repeat launches.
  event.respondWith(
    caches.match(event.request).then(cached=>{
      if(cached)return cached;
      return fetch(event.request).then(response=>{
        if(response&&response.ok){
          const copy=response.clone();
          caches.open(CACHE).then(c=>c.put(event.request,copy));
        }
        return response;
      });
    })
  );
});
