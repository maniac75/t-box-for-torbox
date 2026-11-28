// T-Box para Safari: detecta magnets, enlaces .torrent y archivos de sitios compatibles con TorBox,
// y los manda a T-Box (tbox://add?text=…). No envía nada a ningún servidor.
(() => {
  if (window.top !== window || window.__tboxLoaded) return;
  window.__tboxLoaded = true;

  const B = typeof browser !== 'undefined' ? browser : chrome;
  const ES = (navigator.language || '').toLowerCase().startsWith('es');
  const T = ES ? {
    big: 'Bajar con T-Box', small: 'Sitio compatible con T-Box', hide: 'Ocultar en este sitio', cancel: 'Cancelar',
    pick: 'Elige qué mandar a T-Box', pickNote: 'Se abre T-Box para que confirmes.', page: 'Esta página',
    send: n => `Mandar a T-Box (${n})`, badge: 'Mandar a T-Box', magnet: 'Magnet', torrent: 'Archivo .torrent'
  } : {
    big: 'Download with T-Box', small: 'Works with T-Box', hide: 'Hide on this site', cancel: 'Cancel',
    pick: 'Choose what to send to T-Box', pickNote: 'T-Box opens so you can confirm.', page: 'This page',
    send: n => `Send to T-Box (${n})`, badge: 'Send to T-Box', magnet: 'Magnet', torrent: '.torrent file'
  };

  // Nivel 1: sitios conocidos y cómo son sus páginas de archivo (ruta + query).
  const RULES = [
    { d: ['rapidgator.net', 'rg.to'], p: /^\/file\// },
    { d: ['1fichier.com'], p: /^\/?\?[a-z0-9]{5,}/i },
    { d: ['mega.nz', 'mega.io'], p: /^\/(file|folder)\// },
    { d: ['gofile.io'], p: /^\/d\// },
    { d: ['pixeldrain.com'], p: /^\/(u|l)\// },
    { d: ['mediafire.com'], p: /^\/(file|file_premium|folder|view)\// },
    { d: ['nitroflare.com', 'nitro.download'], p: /^\/view\// },
    { d: ['filefactory.com'], p: /^\/(file|folder)\// },
    { d: ['turbobit.net', 'turb.to', 'turb.cc'], p: /^\/[a-z0-9]+\.html/i },
    { d: ['hitfile.net'], p: /^\/[a-z0-9]{5,}/i },
    { d: ['krakenfiles.com'], p: /^\/view\// },
    { d: ['ddownload.com', 'katfile.com', 'clicknupload.click', 'clicknupload.to', 'send.cm', 'usersdrive.com', 'dropapk.to'],
      p: /^\/[a-z0-9]{8,}/i },
    { d: ['drive.google.com'], p: /^\/(file\/d\/|drive\/folders\/|open\?|uc\?)/ },
    { d: ['dropbox.com'], p: /^\/(s|sh|scl)\// },
    { d: ['youtube.com', 'm.youtube.com'], p: /^\/(watch\?|shorts\/|live\/)/ },
    { d: ['youtu.be'], p: /^\/[\w-]{6,}/ },
    { d: ['vimeo.com'], p: /^\/\d+/ },
    { d: ['instagram.com'], p: /^\/(p|reel|reels|tv)\// },
    { d: ['tiktok.com'], p: /^\/@[^/]+\/video\// },
    { d: ['x.com', 'twitter.com'], p: /^\/[^/]+\/status\// },
    { d: ['reddit.com'], p: /^\/r\/[^/]+\/comments\// },
    { d: ['soundcloud.com'], p: /^\/[^/]+\/[^/]+/ }
  ];
  // Páginas donde nunca hay archivos (nivel 3).
  const SKIP = /^\/(login|signin|sign-in|log-in|register|signup|sign-up|premium|pricing|prices|plans|faq|help|support|contact|about|terms|tos|privacy|account|upload|dashboard|settings|news|blog)(\/|$|\.)/i;

  const matches = (host, d) => { host = host.toLowerCase(); return host === d || host.endsWith('.' + d); };
  let hosters = [];
  const hosterFor = host => hosters.find(h => h.domains.some(d => matches(host, d)));
  const ruleFor = host => RULES.find(r => r.d.some(d => matches(host, d)));
  const rest = u => u.pathname + u.search;

  function isFileURL(u) {
    if (!hosterFor(u.hostname)) return false;
    const rule = ruleFor(u.hostname);
    if (rule) return rule.p.test(rest(u));
    return u.pathname.length > 1 && !SKIP.test(u.pathname);
  }

  function classify(href) {
    if (!href) return null;
    if (/^magnet:\?/i.test(href)) return { kind: 'magnet', url: href };
    let u;
    try { u = new URL(href, location.href); } catch (e) { return null; }
    if (!/^https?:$/.test(u.protocol)) return null;
    if (/\.torrent$/i.test(u.pathname)) return { kind: 'torrent', url: u.href };
    if (u.hostname !== location.hostname && isFileURL(u)) return { kind: 'hoster', url: u.href };
    return null;
  }

  function label(item) {
    if (item.kind === 'magnet') {
      const dn = /[?&]dn=([^&]+)/i.exec(item.url);
      let name = T.magnet;
      if (dn) { try { name = decodeURIComponent(dn[1].replace(/\+/g, ' ')); } catch (e) {} }
      return { title: name, sub: T.magnet };
    }
    const u = new URL(item.url);
    if (item.kind === 'torrent') return { title: decodeURIComponent(u.pathname.split('/').pop()), sub: T.torrent };
    const h = hosterFor(u.hostname);
    return { title: item.url, sub: h ? h.name : u.hostname };
  }

  // MARK: Enviar a T-Box

  function send(urls) {
    if (!urls.length) return;
    const a = document.createElement('a');
    a.href = 'tbox://add?text=' + encodeURIComponent(urls.join('\n'));
    a.style.display = 'none';
    document.body.appendChild(a);
    a.click();
    a.remove();
  }

  const ICON = '<svg viewBox="0 0 160 160" aria-hidden="true"><polygon points="80,18 138,50 80,82 22,50" fill="#7aeba2"/><polygon points="22,50 80,82 80,146 22,114" fill="#2aa866"/><polygon points="138,50 80,82 80,146 138,114" fill="#14663a"/><rect x="74" y="60" width="12" height="28" fill="#fff"/><polygon points="62,86 98,86 80,108" fill="#fff"/></svg>';

  // MARK: Nivel 2: ícono junto a cada enlace compatible

  let items = [];
  function scan() {
    const seen = new Set();
    const found = [];
    document.querySelectorAll('a[href]').forEach(a => {
      const item = classify(a.getAttribute('href'));
      if (!item) return;
      if (!seen.has(item.url)) { seen.add(item.url); found.push(item); }
      if (a.dataset.tbox) return;
      a.dataset.tbox = '1';
      const b = document.createElement('span');
      b.className = 'tbox-badge';
      b.setAttribute('role', 'button');
      b.setAttribute('aria-label', T.badge);
      b.innerHTML = ICON;
      b.addEventListener('click', e => { e.preventDefault(); e.stopPropagation(); send([item.url]); }, true);
      a.insertAdjacentElement('afterend', b);
    });
    items = found;
    updateFab();
  }

  // MARK: Botón flotante (niveles 1 y 3)

  const site = location.hostname.replace(/^www\./, '');
  let hiddenSites = [];
  let seenSites = [];
  let fab = null;

  function pageLevel() {
    if (!hosterFor(location.hostname)) return 0;
    const rule = ruleFor(location.hostname);
    if (rule) return rule.p.test(rest(location)) ? 1 : 0;
    return location.pathname.length > 1 && !SKIP.test(location.pathname) ? 3 : 0;
  }

  function updateFab() {
    const level = pageLevel();
    const want = !hiddenSites.includes(site) && (level > 0 || items.length >= 2);
    if (!want) { if (fab) { fab.remove(); fab = null; } return; }
    if (!fab) {
      fab = document.createElement('button');
      fab.type = 'button';
      fab.className = 'tbox-fab';
      fab.innerHTML = ICON + '<span class="tbox-fab-label"></span>';
      document.body.appendChild(fab);
      bindFab(fab);
      if (level !== 1 && !seenSites.includes(site)) {
        fab.classList.add('tbox-hint');
        seenSites.push(site);
        B.storage.local.set({ seenSites: seenSites.slice(-500) });
        setTimeout(() => fab && fab.classList.remove('tbox-hint'), 3500);
      }
    }
    // Solo se toca el DOM si algo cambió: el observador de cambios volvería a escanear.
    const text = level === 1 ? T.big : T.small;
    const lab = fab.querySelector('.tbox-fab-label');
    if (lab.textContent !== text) lab.textContent = text;
    if (fab.classList.contains('tbox-small') !== (level !== 1)) fab.classList.toggle('tbox-small', level !== 1);
    const aria = level === 1 ? T.big : T.badge;
    if (fab.getAttribute('aria-label') !== aria) fab.setAttribute('aria-label', aria);
  }

  function bindFab(el) {
    let timer = null;
    let longPressed = false;
    const start = () => { longPressed = false; timer = setTimeout(() => { longPressed = true; showMenu(); }, 600); };
    const stop = () => clearTimeout(timer);
    el.addEventListener('touchstart', start, { passive: true });
    el.addEventListener('touchend', stop);
    el.addEventListener('touchmove', stop, { passive: true });
    el.addEventListener('contextmenu', e => { e.preventDefault(); showMenu(); });
    el.addEventListener('click', e => {
      e.preventDefault();
      if (longPressed) { longPressed = false; return; }
      choose();
    });
  }

  function closeOverlays() { document.querySelectorAll('.tbox-backdrop,.tbox-menu,.tbox-sheet').forEach(n => n.remove()); }

  function backdrop() {
    const bd = document.createElement('div');
    bd.className = 'tbox-backdrop';
    bd.addEventListener('click', closeOverlays);
    document.body.appendChild(bd);
  }

  function showMenu() {
    closeOverlays();
    backdrop();
    const m = document.createElement('div');
    m.className = 'tbox-menu';
    const hide = document.createElement('button');
    hide.type = 'button';
    hide.textContent = T.hide;
    hide.addEventListener('click', () => { setHidden(true); closeOverlays(); });
    const cancel = document.createElement('button');
    cancel.type = 'button';
    cancel.textContent = T.cancel;
    cancel.addEventListener('click', closeOverlays);
    m.append(hide, cancel);
    document.body.appendChild(m);
  }

  // Un solo archivo: se manda directo. Varios: lista para elegir.
  function choose() {
    const options = [];
    if (pageLevel() > 0) options.push({ url: location.href, title: T.page, sub: location.hostname, checked: items.length === 0 });
    items.forEach(it => { const l = label(it); options.push({ url: it.url, title: l.title, sub: l.sub, checked: true }); });
    if (options.length === 0) return;
    if (options.length === 1) { send([options[0].url]); return; }
    closeOverlays();
    backdrop();
    const sheet = document.createElement('div');
    sheet.className = 'tbox-sheet';
    const h = document.createElement('h2'); h.textContent = T.pick;
    const p = document.createElement('p'); p.textContent = T.pickNote;
    sheet.append(h, p);
    const boxes = options.map(o => {
      const lab = document.createElement('label');
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.checked = o.checked;
      const txt = document.createElement('span');
      txt.textContent = o.title;
      const small = document.createElement('small');
      small.textContent = o.sub;
      txt.appendChild(small);
      lab.append(cb, txt);
      sheet.appendChild(lab);
      return { cb, url: o.url };
    });
    const go = document.createElement('button');
    go.type = 'button';
    go.className = 'tbox-send';
    const refresh = () => { go.textContent = T.send(boxes.filter(b => b.cb.checked).length); };
    boxes.forEach(b => b.cb.addEventListener('change', refresh));
    refresh();
    go.addEventListener('click', () => { send(boxes.filter(b => b.cb.checked).map(b => b.url)); closeOverlays(); });
    const cancel = document.createElement('button');
    cancel.type = 'button';
    cancel.className = 'tbox-cancel';
    cancel.textContent = T.cancel;
    cancel.addEventListener('click', closeOverlays);
    sheet.append(go, cancel);
    document.body.appendChild(sheet);
  }

  function setHidden(hidden) {
    hiddenSites = hiddenSites.filter(s => s !== site);
    if (hidden) hiddenSites.push(site);
    B.storage.local.set({ hiddenSites });
    updateFab();
  }

  // MARK: Mensajes del botón de extensiones de Safari (popup)

  B.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (!msg) return;
    if (msg.type === 'state') {
      const h = hosterFor(location.hostname);
      sendResponse({
        site, compatible: !!h, hosterName: h ? h.name : null, pageURL: location.href,
        hidden: hiddenSites.includes(site),
        items: items.map(it => Object.assign({ url: it.url }, label(it)))
      });
    } else if (msg.type === 'send') {
      send(msg.urls || []);
      sendResponse(true);
    } else if (msg.type === 'setHidden') {
      setHidden(!!msg.hidden);
      sendResponse(true);
    }
  });

  // MARK: Arranque

  let pending = null;
  const observer = new MutationObserver(() => {
    if (pending) return;
    pending = setTimeout(() => { pending = null; scan(); }, 800);
  });

  Promise.all([
    B.runtime.sendMessage({ type: 'hosters' }).catch(() => []),
    B.storage.local.get(['hiddenSites', 'seenSites']).catch(() => ({}))
  ]).then(([list, saved]) => {
    hosters = Array.isArray(list) ? list : [];
    hiddenSites = saved.hiddenSites || [];
    seenSites = saved.seenSites || [];
    scan();
    observer.observe(document.body, { childList: true, subtree: true });
  });
})();
