// Ventana del botón de extensiones de Safari: lo encontrado en la página y el botón por sitio.
const B = typeof browser !== 'undefined' ? browser : chrome;
const ES = (navigator.language || '').toLowerCase().startsWith('es');
const T = ES ? {
  compatible: n => `Este sitio funciona con T-Box (${n}).`, notCompatible: 'Este sitio no está en la lista de TorBox.',
  nothing: 'No encontré magnets, .torrent ni archivos de sitios compatibles en esta página.',
  noAccess: 'Da permiso a la extensión en este sitio para que pueda revisarlo (botón "aA" › Administrar extensiones).',
  page: 'Esta página', send: n => `Mandar a T-Box (${n})`, show: 'Mostrar el botón en este sitio', hide: 'Ocultar el botón en este sitio'
} : {
  compatible: n => `This site works with T-Box (${n}).`, notCompatible: "This site isn't on TorBox's list.",
  nothing: 'No magnets, .torrent files or supported-site files found on this page.',
  noAccess: 'Allow the extension on this site so it can check it ("aA" button › Manage Extensions).',
  page: 'This page', send: n => `Send to T-Box (${n})`, show: 'Show the button on this site', hide: 'Hide the button on this site'
};

const $ = id => document.getElementById(id);

async function main() {
  const [tab] = await B.tabs.query({ active: true, currentWindow: true });
  let state = null;
  try { state = await B.tabs.sendMessage(tab.id, { type: 'state' }); } catch (e) { state = null; }
  if (!state) { $('status').textContent = T.noAccess; return; }

  const status = $('status');
  if (state.compatible) {
    status.textContent = T.compatible(state.hosterName);
    status.className = 'status ok';
  } else {
    status.textContent = T.notCompatible;
  }

  const options = [];
  if (state.compatible) options.push({ url: state.pageURL, title: T.page, sub: state.site });
  state.items.forEach(it => options.push(it));

  const list = $('list');
  if (!options.length) {
    const p = document.createElement('p');
    p.className = 'empty';
    p.textContent = T.nothing;
    list.appendChild(p);
  }
  const boxes = options.map((o, i) => {
    const lab = document.createElement('label');
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = options.length === 1 || i > 0 || state.items.length === 0;
    const txt = document.createElement('span');
    txt.textContent = o.title;
    const small = document.createElement('small');
    small.textContent = o.sub;
    txt.appendChild(small);
    lab.append(cb, txt);
    list.appendChild(lab);
    return { cb, url: o.url };
  });

  const send = $('send');
  const refresh = () => {
    const n = boxes.filter(b => b.cb.checked).length;
    send.textContent = T.send(n);
    send.disabled = n === 0;
  };
  if (boxes.length) {
    send.hidden = false;
    boxes.forEach(b => b.cb.addEventListener('change', refresh));
    refresh();
    send.addEventListener('click', async () => {
      await B.tabs.sendMessage(tab.id, { type: 'send', urls: boxes.filter(b => b.cb.checked).map(b => b.url) });
      window.close();
    });
  }

  if (state.compatible || state.items.length) {
    const toggle = $('toggle');
    toggle.hidden = false;
    let hidden = state.hidden;
    const label = () => { toggle.textContent = hidden ? T.show : T.hide; };
    label();
    toggle.addEventListener('click', async () => {
      hidden = !hidden;
      await B.tabs.sendMessage(tab.id, { type: 'setHidden', hidden });
      label();
    });
  }
}

main();
