// T-Box: lista de sitios compatibles de TorBox (hosters), guardada un día.
// Es la misma lista pública que usa la app (no necesita API key).
const API = 'https://api.torbox.app/v1/api/webdl/hosters';
const DAY = 24 * 60 * 60 * 1000;
const B = typeof browser !== 'undefined' ? browser : chrome;

async function hosters() {
  const saved = await B.storage.local.get(['hosters', 'hostersAt']);
  if (saved.hosters && saved.hostersAt && Date.now() - saved.hostersAt < DAY) return saved.hosters;
  try {
    const res = await fetch(API);
    const json = await res.json();
    const list = (json.data || [])
      .filter(h => Array.isArray(h.domains) && h.domains.length)
      .map(h => ({ name: String(h.name || ''), domains: h.domains.map(d => String(d).toLowerCase()) }));
    if (list.length) {
      await B.storage.local.set({ hosters: list, hostersAt: Date.now() });
      return list;
    }
  } catch (e) { /* sin red: se usa lo guardado, aunque sea viejo */ }
  return saved.hosters || [];
}

B.runtime.onMessage.addListener((msg, sender, sendResponse) => {
  if (msg && msg.type === 'hosters') {
    hosters().then(sendResponse);
    return true; // respuesta asíncrona
  }
});
