// ===== Constants, storage, state, undo, backups, photos =====
const APP_VERSION = '2.0 (web)';
const COLORS = ['purple', 'teal', 'coral', 'pink', 'blue', 'green', 'orange', 'red'];
const HOUSE_ICONS = ['🏠', '🏡', '🏘️', '🏚️', '🏗️', '🏢', '🏣', '🏤'];
const SECTION_COLORS = ['blue', 'orange', 'teal', 'pink', 'purple', 'green', 'coral', 'red'];
const ROLES = ['Grandparent', 'Parent', 'Child', 'Other'];
const GENDERS = ['Male', 'Female', 'Other'];
const ROLE_ICON = { Grandparent: '👴', Parent: '👪', Child: '🧒', Other: '🧑' };
const GENDER_ICON = { Male: '👨', Female: '👩', Other: '🧑' };
const ZOOMS = [0.6, 0.75, 1, 1.25, 1.5, 1.8, 2.2];
const GAP = 3;
const MAX_ROWS = 80, MAX_COLS = 30;
const DEFAULT_SETTINGS = {
  grass: 'mint', lang: 'auto', birthdayHour: 9, dayBefore: false,
  favorites: ['🌳', '⛩️', '🪧', '🌸'], recent: [], zoom: 2, lastFileBackup: null,
};

// ----- key/value storage: IndexedDB first, localStorage as a fallback -----
let db = null;
let usingFallback = false;

function openDB() {
  return new Promise((resolve, reject) => {
    if (!window.indexedDB) { reject(new Error('IndexedDB is not available')); return; }
    let rq;
    try { rq = indexedDB.open('neighborhoodskout', 1); } catch (e) { reject(e); return; }
    rq.onupgradeneeded = () => { rq.result.createObjectStore('kv'); };
    rq.onsuccess = () => resolve(rq.result);
    rq.onerror = () => reject(rq.error);
    rq.onblocked = () => reject(new Error('blocked'));
  });
}
function idbReq(mode, fn) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction('kv', mode);
    const store = tx.objectStore('kv');
    let result;
    const rq = fn(store);
    if (rq) rq.onsuccess = () => { result = rq.result; };
    tx.oncomplete = () => resolve(result);
    tx.onerror = () => reject(tx.error);
    tx.onabort = () => reject(tx.error || new Error('aborted'));
  });
}
const LS_PREFIX = 'nsk:';
const kv = {
  async get(k) {
    if (!usingFallback) return idbReq('readonly', (s) => s.get(k));
    const raw = localStorage.getItem(LS_PREFIX + k);
    return raw === null ? undefined : JSON.parse(raw);
  },
  async set(k, v) {
    if (!usingFallback) return idbReq('readwrite', (s) => s.put(v, k));
    localStorage.setItem(LS_PREFIX + k, JSON.stringify(v));
  },
  async del(k) {
    if (!usingFallback) return idbReq('readwrite', (s) => s.delete(k));
    localStorage.removeItem(LS_PREFIX + k);
  },
  async keys() {
    if (!usingFallback) return idbReq('readonly', (s) => s.getAllKeys());
    return Object.keys(localStorage).filter((k) => k.startsWith(LS_PREFIX)).map((k) => k.slice(LS_PREFIX.length));
  },
};

// ----- state -----
let S = blankState();
let settings = clone(DEFAULT_SETTINGS);
let blockIndex = new Map();      // "r,c" -> block
let saveStatus = { ok: true, at: null, error: null, persisted: null };

function blankState() {
  return { version: 2, columns: 6, rows: 16, blocks: [], sections: [], savedAt: null };
}
function normalizeState(s) {
  const out = blankState();
  if (!s || typeof s !== 'object') return out;
  out.columns = Math.max(6, Math.min(MAX_COLS, s.columns | 0 || 6));
  out.rows = Math.max(4, Math.min(MAX_ROWS, s.rows | 0 || 16));
  out.blocks = (Array.isArray(s.blocks) ? s.blocks : []).map((b) => ({
    id: b.id || uid(), kind: b.kind === 'road' || b.kind === 'decoration' ? b.kind : 'house',
    row: b.row | 0, col: b.col | 0,
    houseName: b.houseName || '', colorName: COLORS.includes(b.colorName) ? b.colorName : 'purple',
    icon: b.icon || '🏠', decoration: b.decoration || null,
    residents: (Array.isArray(b.residents) ? b.residents : []).map(normPerson),
    lastModified: b.lastModified || nowISO(),
  }));
  out.sections = (Array.isArray(s.sections) ? s.sections : []).map((x) => ({
    id: x.id || uid(), name: x.name || '', colorName: COLORS.includes(x.colorName) ? x.colorName : 'blue',
    cells: (Array.isArray(x.cells) ? x.cells : []).map((c) => [c[0] | 0, c[1] | 0]),
    lastModified: x.lastModified || nowISO(),
  }));
  out.savedAt = s.savedAt || null;
  // grow the grid if any block sits outside it, so nothing is ever hidden
  for (const b of out.blocks) {
    if (b.row >= out.rows) out.rows = Math.min(MAX_ROWS, b.row + 1);
    if (b.col >= out.columns) out.columns = Math.min(MAX_COLS, b.col + 1);
  }
  return out;
}
function normPerson(p) {
  return {
    id: p.id || uid(), firstName: p.firstName || '', lastName: p.lastName || '',
    gender: GENDERS.includes(p.gender) ? p.gender : 'Other',
    role: ROLES.includes(p.role) ? p.role : 'Other',
    birthday: p.birthday || '', lineId: p.lineId || '', phone: p.phone || '',
    email: p.email || '', notes: p.notes || '', lastModified: p.lastModified || nowISO(),
  };
}
function reindex() {
  blockIndex = new Map();
  for (const b of S.blocks) blockIndex.set(`${b.row},${b.col}`, b);
}
const blockAt = (r, c) => blockIndex.get(`${r},${c}`) || null;
const blockById = (id) => S.blocks.find((b) => b.id === id) || null;
const houses = () => S.blocks.filter((b) => b.kind === 'house');
function sectionAt(r, c) { return S.sections.find((x) => x.cells.some((p) => p[0] === r && p[1] === c)) || null; }
function sectionOfBlock(b) { return b ? sectionAt(b.row, b.col) : null; }
function findPerson(personId) {
  for (const b of S.blocks) for (const p of b.residents) if (p.id === personId) return { block: b, person: p };
  return null;
}

// ----- saving (every change, immediately, with a visible error if it fails) -----
let saveTimer = null;
let onSaveStatus = () => {};
let onLocalSaved = () => {};   // set by the sync code when a home server is present
function scheduleSave() {
  clearTimeout(saveTimer);
  saveTimer = setTimeout(doSave, 40);
}
async function doSave() {
  clearTimeout(saveTimer); saveTimer = null;
  try {
    S.savedAt = nowISO();
    await kv.set('state', S);
    saveStatus = { ...saveStatus, ok: true, at: new Date(), error: null };
    try { onLocalSaved(); } catch (e) { /* sync is optional */ }
  } catch (e) {
    saveStatus = { ...saveStatus, ok: false, error: String(e && e.message || e) };
  }
  onSaveStatus();
}
async function saveSettings() {
  try { await kv.set('settings', settings); } catch (e) { saveStatus = { ...saveStatus, ok: false, error: String(e && e.message || e) }; onSaveStatus(); }
}
function flushSave() { if (saveTimer) doSave(); }

// ----- undo (in memory, last 20 changes) -----
const history = [];
let strokeOpen = false, strokePushed = false;
function pushUndo() {
  if (strokeOpen) { if (strokePushed) return; strokePushed = true; }
  history.push(JSON.stringify(S));
  if (history.length > 20) history.shift();
}
function beginStroke() { strokeOpen = true; strokePushed = false; }
function endStroke() { strokeOpen = false; strokePushed = false; }
function canUndo() { return history.length > 0; }
function undo() {
  if (!history.length) return false;
  S = normalizeState(JSON.parse(history.pop()));
  reindex(); scheduleSave();
  return true;
}
function clearHistory() { history.length = 0; }

// ----- backups (kept inside the browser, up to 10 automatic + 10 manual) -----
async function getBackups() { return (await kv.get('backups').catch(() => null)) || []; }
async function addBackup(label, kind) {
  if (!S.blocks.length && !S.sections.length) return null;
  const list = await getBackups();
  const entry = {
    id: uid(), at: nowISO(), label, kind, houses: houses().length,
    people: S.blocks.reduce((n, b) => n + b.residents.length, 0), json: JSON.stringify(S),
  };
  list.unshift(entry);
  const keep = [];
  let auto = 0, manual = 0;
  for (const b of list) {
    if (b.kind === 'manual') { if (manual++ < 10) keep.push(b); }
    else if (auto++ < 10) keep.push(b);
  }
  await kv.set('backups', keep);
  return entry;
}
async function deleteBackup(id) {
  const list = (await getBackups()).filter((b) => b.id !== id);
  await kv.set('backups', list);
}

// ----- photos (stored as small JPEG blobs, one per house or person id) -----
const photoUrls = new Map();     // id -> object URL
async function loadPhotos() {
  if (usingFallback) return;
  const keys = await kv.keys();
  for (const k of keys) {
    if (typeof k === 'string' && k.startsWith('photo:')) {
      const blob = await kv.get(k);
      if (blob) photoUrls.set(k.slice(6), URL.createObjectURL(blob));
    }
  }
}
async function setPhoto(id, blob) {
  if (usingFallback) throw new Error('Photos need browser storage, which is not available here.');
  await kv.set('photo:' + id, blob);
  if (photoUrls.has(id)) URL.revokeObjectURL(photoUrls.get(id));
  photoUrls.set(id, URL.createObjectURL(blob));
  try { onLocalSaved(); } catch (e) { /* sync is optional */ }
}
async function removePhoto(id) {
  if (photoUrls.has(id)) { URL.revokeObjectURL(photoUrls.get(id)); photoUrls.delete(id); }
  if (!usingFallback) await kv.del('photo:' + id);
  try { onLocalSaved(); } catch (e) { /* sync is optional */ }
}
const photoOf = (id) => photoUrls.get(id) || null;

function loadImage(url) {
  return new Promise((res, rej) => { const i = new Image(); i.onload = () => res(i); i.onerror = () => rej(new Error('Could not read that image')); i.src = url; });
}
async function resizeImage(file, max = 720) {
  const url = URL.createObjectURL(file);
  try {
    const img = await loadImage(url);
    const scale = Math.min(1, max / Math.max(img.naturalWidth, img.naturalHeight));
    const w = Math.max(1, Math.round(img.naturalWidth * scale)), hh = Math.max(1, Math.round(img.naturalHeight * scale));
    const c = h('canvas', { width: w, height: hh });
    c.getContext('2d').drawImage(img, 0, 0, w, hh);
    return await new Promise((res, rej) => c.toBlob((b) => (b ? res(b) : rej(new Error('Could not convert the image'))), 'image/jpeg', 0.82));
  } finally { URL.revokeObjectURL(url); }
}
function blobToDataURL(blob) {
  return new Promise((res, rej) => { const r = new FileReader(); r.onload = () => res(r.result); r.onerror = () => rej(r.error); r.readAsDataURL(blob); });
}
async function dataURLToBlob(url) { return (await fetch(url)).blob(); }

// ----- startup -----
async function initStorage() {
  try { db = await openDB(); await idbReq('readonly', (s) => s.get('state')); }
  catch (e) { usingFallback = true; saveStatus.error = 'Browser storage is unavailable, using a smaller fallback. Photos will not be saved.'; }
  const savedSettings = await kv.get('settings').catch(() => null);
  settings = { ...clone(DEFAULT_SETTINGS), ...(savedSettings || {}) };
  const savedState = await kv.get('state').catch(() => null);
  S = savedState ? normalizeState(savedState) : blankState();
  reindex();
  await loadPhotos().catch(() => {});
  try {
    if (navigator.storage && navigator.storage.persist) {
      saveStatus.persisted = (await navigator.storage.persisted()) || (await navigator.storage.persist());
    }
  } catch (e) { /* not available */ }
  // automatic backup once per hour at most, and always before the first change in a session
  try {
    const list = await getBackups();
    const lastAuto = list.find((b) => b.kind === 'auto');
    if (S.blocks.length && (!lastAuto || Date.now() - new Date(lastAuto.at).getTime() > 3600 * 1000)) await addBackup('Automatic backup', 'auto');
  } catch (e) { /* ignore */ }
}
