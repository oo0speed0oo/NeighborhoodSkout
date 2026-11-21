// ===== Sync with your home server =====
// Only active when this page is served by server.py (it answers /api/ping). On any other
// address (a website, a file on your computer) nothing here runs and the app stays local-only.
const sync = { enabled: false, online: false, busy: false, paused: false, again: false, rev: null, dirty: false, seq: 0, lastOk: null, error: null };
let syncTimer = null;

async function syncApi(method, path, opts = {}) {
  const ctl = new AbortController();
  const to = setTimeout(() => ctl.abort(), 15000);
  try {
    return await fetch('api/' + path, { method, body: opts.body, headers: { 'X-Skout': '1', ...(opts.headers || {}) }, signal: ctl.signal, cache: 'no-store' });
  } finally { clearTimeout(to); }
}
async function syncLoadMeta() {
  const m = (await kv.get('syncmeta').catch(() => null)) || {};
  sync.rev = m.rev === undefined ? null : m.rev;
  sync.dirty = !!m.dirty;
}
async function syncSaveMeta() { try { await kv.set('syncmeta', { rev: sync.rev, dirty: sync.dirty }); } catch (e) { /* ignore */ } }
const syncHasData = () => S.blocks.length > 0 || S.sections.length > 0;
function syncCanInterrupt() {
  return !document.body.classList.contains('modal-open') && !sheetOpen && !ui.moving && !strokeOpen && !document.querySelector('.overlay');
}

function syncStatusText() {
  if (sync.paused) return t('Sync paused: choose which map to keep.');
  if (sync.busy) return t('Syncing…');
  if (!sync.online && sync.error) return t('Offline: changes are saved on this device and will sync later.');
  if (sync.dirty) return t('Waiting to sync…');
  return sync.lastOk ? t('Last synced: {0}', sync.lastOk.toLocaleTimeString()) : t('Not synced yet');
}
function updateSyncUI() {
  const el = $('#syncDot');
  if (!el) return;
  el.hidden = !sync.enabled;
  if (!sync.enabled) return;
  let cls = 'ok', txt = '☁ ✓';
  if (sync.paused) { cls = 'bad'; txt = '☁ !'; }
  else if (sync.busy) { cls = ''; txt = '☁ …'; }
  else if (!sync.online && sync.error) { cls = 'bad'; txt = '☁ ✕'; }
  else if (sync.dirty) { cls = 'warn'; txt = '☁ ↑'; }
  el.className = 'syncdot ' + cls;
  el.textContent = txt;
  el.title = syncStatusText();
  el.setAttribute('aria-label', syncStatusText());
  refreshModals();
}

async function syncServerInfo() {
  const r = await syncApi('GET', 'ping');
  if (!r.ok) throw new Error('Server answered ' + r.status);
  return r.json();   // { rev, houses, people }
}

async function syncStart() {
  if (!/^https?:$/.test(location.protocol)) return false;   // a file opened from disk: local-only
  try {
    const r = await syncApi('GET', 'ping');
    if (!r.ok) return false;
    const j = await r.json();
    if (!j || j.app !== 'NeighborhoodSkout-server') return false;
  } catch (e) { return false; }
  sync.enabled = true;
  await syncLoadMeta();
  onLocalSaved = () => {
    if (!sync.enabled) return;
    sync.seq++; sync.dirty = true; syncSaveMeta(); updateSyncUI();
    if (!sync.paused) syncSchedule(1500);
  };
  $('#syncDot').addEventListener('click', () => { syncNow({ manual: true }).then(() => toast(syncStatusText())); });
  document.addEventListener('visibilitychange', () => { if (document.visibilityState === 'visible') syncNow(); });
  window.addEventListener('focus', () => syncNow());
  window.addEventListener('online', () => syncNow());
  setInterval(() => { if (document.visibilityState === 'visible') syncNow(); }, 30000);
  updateSyncUI();
  syncNow({ startup: true });
  return true;
}

function syncSchedule(ms) { clearTimeout(syncTimer); syncTimer = setTimeout(() => syncNow(), ms); }

async function syncNow(opts = {}) {
  if (!sync.enabled) return;
  if (sync.busy) { sync.again = true; return; }
  if (sync.paused && !opts.manual) return;
  if (opts.manual) sync.paused = false;
  sync.busy = true; updateSyncUI();
  try {
    flushSave();
    await syncRun();
    sync.online = true; sync.error = null; if (!sync.paused) sync.lastOk = new Date();
  } catch (e) {
    sync.online = false; sync.error = String((e && e.message) || e);
  } finally {
    sync.busy = false; updateSyncUI();
    if (sync.again) { sync.again = false; syncSchedule(300); }
  }
}

async function syncRun() {
  const info = await syncServerInfo();
  const srv = info.rev;
  if (srv === '0') {                                   // server has no map yet
    if (syncHasData()) await syncPush('0');
    else { sync.rev = '0'; sync.dirty = false; await syncSaveMeta(); }
    return;
  }
  if (sync.rev === srv) { if (sync.dirty) await syncPush(srv); return; }
  // the server's map is different from the one this device last saw
  if (sync.rev === null && !syncHasData()) return syncPull(true);
  if (sync.rev !== null && !sync.dirty) {
    if (!syncCanInterrupt()) { syncSchedule(4000); return; }
    return syncPull(true);
  }
  return syncAskConflict(info);                         // both changed (or first connection with a map on both sides)
}

async function syncPhotoList() {
  const r = await syncApi('GET', 'photos');
  if (!r.ok) throw new Error('Server answered ' + r.status);
  return r.json();   // [{id,size}]
}
async function syncPhotosUp() {            // upload what the server lacks (before the map is committed)
  if (usingFallback) return;
  const remote = new Map((await syncPhotoList()).map((x) => [x.id, x.size]));
  for (const id of photoUrls.keys()) {
    const blob = await kv.get('photo:' + id).catch(() => null);
    if (!blob) continue;
    if (remote.get(id) !== blob.size) {
      const r = await syncApi('PUT', 'photo/' + encodeURIComponent(id), { body: blob, headers: { 'Content-Type': 'image/jpeg' } });
      if (!r.ok) throw new Error('Photo upload failed (' + r.status + ')');
    }
  }
}
async function syncPhotosTrim() {          // after a successful push, remove photos this device no longer has
  if (usingFallback) return;
  for (const x of await syncPhotoList()) if (!photoUrls.has(x.id)) await syncApi('DELETE', 'photo/' + encodeURIComponent(x.id));
}
async function syncPhotosDown() {          // make this device's photos match the server's
  if (usingFallback) return;
  const list = await syncPhotoList();
  const keep = new Set(list.map((x) => x.id));
  for (const x of list) {
    const have = photoUrls.has(x.id) ? await kv.get('photo:' + x.id).catch(() => null) : null;
    if (have && have.size === x.size) continue;
    const r = await syncApi('GET', 'photo/' + encodeURIComponent(x.id));
    if (!r.ok) continue;
    const blob = await r.blob();
    await kv.set('photo:' + x.id, blob);
    if (photoUrls.has(x.id)) URL.revokeObjectURL(photoUrls.get(x.id));
    photoUrls.set(x.id, URL.createObjectURL(blob));
  }
  for (const id of [...photoUrls.keys()]) {
    if (keep.has(id)) continue;
    URL.revokeObjectURL(photoUrls.get(id)); photoUrls.delete(id);
    await kv.del('photo:' + id).catch(() => {});
  }
}

async function syncPush(ifMatch) {
  const seq = sync.seq;
  await syncPhotosUp();
  const r = await syncApi('PUT', 'state', { body: JSON.stringify(S), headers: { 'Content-Type': 'application/json', 'If-Match': ifMatch } });
  if (r.status === 412) return syncAskConflict(await syncServerInfo());
  if (!r.ok) throw new Error('Server answered ' + r.status);
  const j = await r.json();
  await syncPhotosTrim();
  sync.rev = j.rev;
  if (sync.seq === seq) sync.dirty = false;
  await syncSaveMeta();
  if (sync.dirty) syncSchedule(500);
}

async function syncPull(announce) {
  const seq = sync.seq;
  const r = await syncApi('GET', 'state');
  if (!r.ok) throw new Error('Server answered ' + r.status);
  const rev = r.headers.get('X-Rev');
  const remote = normalizeState(await r.json());
  if (sync.seq !== seq) { sync.again = true; return; }          // you edited while we were fetching: decide again
  if (syncHasData()) await addBackup(t('Before sync'), 'auto').catch(() => {});
  await syncPhotosDown();
  S = remote; reindex(); clearHistory();
  await kv.set('state', S);
  sync.rev = rev; sync.dirty = false; await syncSaveMeta();
  ui.moving = null; ui.moveSrc = null;
  renderAll();
  if (announce && syncHasData()) toast(t('Updated from your other device.'));
}

function syncAskConflict(info) {
  if (sync.paused) return;
  sync.paused = true; updateSyncUI();
  const mine = countsOf(S);
  openSheet(t('The server and this device have different maps'), t('Your current map is backed up first.'), [
    { label: t('Use the server map ({0} houses, {1} people)', info.houses, info.people), onClick: () => syncResolve(async () => { await syncPull(true); }) },
    { label: t("Keep this device's map ({0} houses, {1} people)", mine.houses, mine.people), onClick: () => syncResolve(async () => { await syncPush(info.rev); }) },
  ]);
}
async function syncResolve(fn) {
  sync.paused = false;
  if (sync.busy) { sync.again = true; return; }
  sync.busy = true; updateSyncUI();
  try { flushSave(); await fn(); sync.online = true; sync.error = null; sync.lastOk = new Date(); }
  catch (e) { sync.online = false; sync.error = String((e && e.message) || e); }
  finally { sync.busy = false; updateSyncUI(); }
}
