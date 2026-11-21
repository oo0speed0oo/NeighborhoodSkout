// ===== Map and people changes, birthdays, v1 conversion =====
let onChange = () => {};

function mutate(fn, opts = {}) {
  if (opts.undo !== false) pushUndo();
  fn();
  reindex();
  scheduleSave();
  onChange();
}
const touch = (obj) => { obj.lastModified = nowISO(); return obj; };

function firstEmptyCell() {
  for (let r = 0; r < S.rows; r++) for (let c = 0; c < S.columns; c++) if (!blockAt(r, c)) return [r, c];
  return null;
}
function ensureRoom() { // add a row if the grid is completely full
  if (!firstEmptyCell() && S.rows < MAX_ROWS) S.rows++;
}

function newHouseBlock(r, c) {
  const hs = houses();
  let n = hs.length + 1;
  const names = new Set(hs.map((b) => b.houseName));
  while (names.has(t('House {0}', n))) n++;
  return {
    id: uid(), kind: 'house', row: r, col: c, houseName: t('House {0}', n),
    colorName: COLORS[(hs.length) % COLORS.length], icon: HOUSE_ICONS[(hs.length) % HOUSE_ICONS.length],
    decoration: null, residents: [], lastModified: nowISO(),
  };
}
function removeBlockAt(r, c) { S.blocks = S.blocks.filter((b) => !(b.row === r && b.col === c)); }

// Tap on empty grass in normal mode.
function createHouseAt(r, c) {
  let created = null;
  mutate(() => { created = newHouseBlock(r, c); S.blocks.push(created); });
  return created;
}

// Edit Map painting. tool: {type:'grass'|'road'|'house'|'emoji'|'section', emoji?, sectionId?}
// Returns true if something changed.
function paintCell(r, c, tool) {
  if (r < 0 || c < 0 || r >= S.rows || c >= S.columns) return false;
  const cur = blockAt(r, c);
  if (tool.type === 'section') {
    const target = tool.sectionId ? S.sections.find((x) => x.id === tool.sectionId) : null;
    const now = sectionAt(r, c);
    if ((now && now.id) === (target && target.id)) return false;
    mutate(() => {
      for (const x of S.sections) {
        const i = x.cells.findIndex((p) => p[0] === r && p[1] === c);
        if (i >= 0) { x.cells.splice(i, 1); touch(x); }
      }
      if (target) { target.cells.push([r, c]); touch(target); }
    });
    return true;
  }
  if (tool.type === 'grass') {
    if (!cur) return false;
    mutate(() => removeBlockAt(r, c));
    return true;
  }
  if (tool.type === 'road') {
    if (cur && cur.kind === 'road') return false;
    mutate(() => { removeBlockAt(r, c); S.blocks.push({ id: uid(), kind: 'road', row: r, col: c, houseName: '', colorName: 'purple', icon: '', decoration: null, residents: [], lastModified: nowISO() }); });
    return true;
  }
  if (tool.type === 'house') {
    if (cur && cur.kind === 'house') return false;
    mutate(() => { removeBlockAt(r, c); S.blocks.push(newHouseBlock(r, c)); });
    return true;
  }
  if (tool.type === 'emoji') {
    if (cur && cur.kind === 'decoration' && cur.icon === tool.emoji) return false;
    mutate(() => { removeBlockAt(r, c); S.blocks.push({ id: uid(), kind: 'decoration', row: r, col: c, houseName: '', colorName: 'purple', icon: tool.emoji, decoration: null, residents: [], lastModified: nowISO() }); });
    return true;
  }
  return false;
}

function moveBlock(id, r, c) {
  const b = blockById(id);
  if (!b || blockAt(r, c) || r < 0 || c < 0 || r >= S.rows || c >= S.columns) return false;
  mutate(() => { b.row = r; b.col = c; touch(b); });
  return true;
}
function deleteBlock(id) {
  const b = blockById(id);
  if (!b) return;
  mutate(() => { S.blocks = S.blocks.filter((x) => x.id !== id); });
}
function updateHouse(id, fields) {
  const b = blockById(id);
  if (!b) return;
  mutate(() => { Object.assign(b, fields); touch(b); });
}

// ----- rows and columns -----
function addRow() { if (S.rows >= MAX_ROWS) return false; mutate(() => { S.rows++; }); return true; }
function addColumn() { if (S.columns >= MAX_COLS) return false; mutate(() => { S.columns++; }); return true; }
function canRemoveRow() { return S.rows > 4 && !S.blocks.some((b) => b.row === S.rows - 1); }
function canRemoveColumn() { return S.columns > 6 && !S.blocks.some((b) => b.col === S.columns - 1); }
function removeRow() {
  if (!canRemoveRow()) return false;
  mutate(() => { S.rows--; for (const x of S.sections) x.cells = x.cells.filter((p) => p[0] < S.rows); });
  return true;
}
function removeColumn() {
  if (!canRemoveColumn()) return false;
  mutate(() => { S.columns--; for (const x of S.sections) x.cells = x.cells.filter((p) => p[1] < S.columns); });
  return true;
}

// ----- sections -----
function addSection(name, colorName) {
  const sec = { id: uid(), name, colorName, cells: [], lastModified: nowISO() };
  mutate(() => { S.sections.push(sec); }, { undo: false });
  return sec;
}
function updateSection(id, fields) {
  const x = S.sections.find((s) => s.id === id);
  if (!x) return;
  mutate(() => { Object.assign(x, fields); touch(x); }, { undo: false });
}
function deleteSection(id) { mutate(() => { S.sections = S.sections.filter((s) => s.id !== id); }); }
function sectionAnchor(sec) { // the top-left cell, where the name chip is drawn
  let best = null;
  for (const p of sec.cells) if (!best || p[0] < best[0] || (p[0] === best[0] && p[1] < best[1])) best = p;
  return best;
}
function nextSectionColor() {
  const used = S.sections.map((s) => s.colorName);
  return SECTION_COLORS.find((c) => !used.includes(c)) || SECTION_COLORS[S.sections.length % SECTION_COLORS.length];
}

// ----- people -----
function blankPerson() {
  return normPerson({ id: uid(), firstName: '', lastName: '', gender: 'Female', role: 'Parent' });
}
function savePerson(houseId, person) {
  const b = blockById(houseId);
  if (!b) return;
  mutate(() => {
    touch(person);
    const i = b.residents.findIndex((p) => p.id === person.id);
    if (i >= 0) b.residents[i] = person; else b.residents.push(person);
    touch(b);
  }, { undo: false });
}
function deletePerson(houseId, personId) {
  const b = blockById(houseId);
  if (!b) return;
  mutate(() => { b.residents = b.residents.filter((p) => p.id !== personId); touch(b); });
}
const fullName = (p) => [p.firstName, p.lastName].filter(Boolean).join(' ').trim();
function ageOn(person, today = new Date()) {
  if (!person.birthday) return null;
  const { y, m, d } = splitYMD(person.birthday);
  let age = today.getFullYear() - y;
  if (today.getMonth() + 1 < m || (today.getMonth() + 1 === m && today.getDate() < d)) age--;
  return age;
}

// ----- birthdays -----
function nextBirthday(person, today = new Date()) {
  if (!person.birthday) return null;
  const { y, m, d } = splitYMD(person.birthday);
  const t0 = new Date(today.getFullYear(), today.getMonth(), today.getDate());
  const make = (yr) => {
    let dd = d, mm = m;
    if (m === 2 && d === 29 && !(yr % 4 === 0 && (yr % 100 !== 0 || yr % 400 === 0))) dd = 28;
    return new Date(yr, mm - 1, dd);
  };
  let when = make(t0.getFullYear());
  if (when < t0) when = make(t0.getFullYear() + 1);
  return { date: when, days: Math.round((when - t0) / 86400000), turns: when.getFullYear() - y };
}
function upcomingBirthdays(withinDays = 60, today = new Date()) {
  const out = [];
  for (const b of S.blocks) {
    if (b.kind !== 'house') continue;
    for (const p of b.residents) {
      const nb = nextBirthday(p, today);
      if (nb && nb.days <= withinDays) out.push({ person: p, block: b, ...nb });
    }
  }
  return out.sort((a, b) => a.days - b.days || fullName(a.person).localeCompare(fullName(b.person)));
}
function houseHasBirthdaySoon(b, days = 7) {
  return b.kind === 'house' && b.residents.some((p) => { const nb = nextBirthday(p); return nb && nb.days <= days; });
}
function placeLabel(b) {
  const sec = sectionOfBlock(b);
  return sec && sec.name ? `${b.houseName} (${sec.name})` : b.houseName;
}

function icsEscape(s) { return String(s).replace(/\\/g, '\\\\').replace(/;/g, '\\;').replace(/,/g, '\\,').replace(/\r?\n/g, '\\n'); }
function foldLine(line) {
  const out = []; let cur = '';
  for (const ch of line) { if ((cur + ch).length > 70) { out.push(cur); cur = ' ' + ch; } else cur += ch; }
  out.push(cur);
  return out.join('\r\n');
}
// A calendar file with one yearly all-day event per birthday, each with a reminder.
function buildBirthdayICS() {
  const lines = ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//NeighborhoodSkout//Birthdays//EN', 'CALSCALE:GREGORIAN', 'X-WR-CALNAME:' + icsEscape(t('Neighbor birthdays'))];
  const stamp = new Date().toISOString().replace(/[-:]/g, '').replace(/\.\d{3}/, '');
  const hr = settings.birthdayHour | 0;
  let n = 0;
  for (const b of S.blocks) {
    if (b.kind !== 'house') continue;
    for (const p of b.residents) {
      const nb = nextBirthday(p);
      if (!nb) continue;
      n++;
      const ds = `${nb.date.getFullYear()}${pad2(nb.date.getMonth() + 1)}${pad2(nb.date.getDate())}`;
      const { y, m, d } = splitYMD(p.birthday);
      lines.push('BEGIN:VEVENT');
      lines.push(`UID:${p.id}@neighborhoodskout`);
      lines.push(`DTSTAMP:${stamp}`);
      lines.push(`DTSTART;VALUE=DATE:${ds}`);
      lines.push('RRULE:FREQ=YEARLY');
      lines.push(foldLine('SUMMARY:' + icsEscape(`🎂 ${fullName(p) || '?'} — ${placeLabel(b)}`)));
      lines.push(foldLine('DESCRIPTION:' + icsEscape(`${fullName(p)} · ${placeLabel(b)} · ${y}-${pad2(m)}-${pad2(d)}`)));
      lines.push('TRANSP:TRANSPARENT');
      lines.push('BEGIN:VALARM', 'ACTION:DISPLAY', foldLine('DESCRIPTION:' + icsEscape(`🎂 ${fullName(p)}`)), `TRIGGER:PT${hr}H`, 'END:VALARM');
      if (settings.dayBefore) lines.push('BEGIN:VALARM', 'ACTION:DISPLAY', foldLine('DESCRIPTION:' + icsEscape(`🎂 ${fullName(p)} (tomorrow)`)), `TRIGGER:-PT${24 - hr}H`, 'END:VALARM');
      lines.push('END:VEVENT');
    }
  }
  lines.push('END:VCALENDAR');
  return { text: lines.join('\r\n') + '\r\n', count: n };
}

// ----- LINE -----
function cleanLineId(raw) {
  let s = String(raw || '').replace(/\s+/g, '');
  while (s.startsWith('~')) s = s.slice(1);
  return s;
}
function lineWebUrl(id) {
  const c = cleanLineId(id);
  return c.startsWith('@') ? `https://line.me/R/ti/p/${encodeURIComponent(c)}` : `https://line.me/R/ti/p/~${encodeURIComponent(c)}`;
}
function lineAppUrl(id) {
  const c = cleanLineId(id);
  return c.startsWith('@') ? `line://ti/p/${encodeURIComponent(c)}` : `line://ti/p/~${encodeURIComponent(c)}`;
}

// ===== Converting the old street-based data (v1) into the grid =====
const LEGACY_TEMPLATES = {
  'Houses Both Sides': { cols: 3, house: [0, 2], road: [1] },
  'Houses Left Side': { cols: 3, house: [0], road: [1, 2] },
  'Houses Right Side': { cols: 3, house: [2], road: [0, 1] },
  'Cul-de-sac': { cols: 2, house: [0, 1], road: [] },
};
function legacyDate(v) {
  if (v === null || v === undefined || v === '') return '';
  if (typeof v === 'number') return ymdFromDate(new Date((v + 978307200) * 1000)); // Swift reference date
  return parseDateLoose(String(v)) || '';
}
// store: { streets:[{id,name,template,rows}], blocks:[{id,houseName,colorName,icon,gridIndex,row,col,residents,decoration}] }
function convertLegacyStore(store) {
  const out = blankState();
  const streets = Array.isArray(store.streets) ? store.streets : [];
  const blocks = Array.isArray(store.blocks) ? store.blocks : [];
  const COLS = 6;
  let rowOffset = 0;
  const placed = new Set();
  const spill = [];
  streets.forEach((st, gi) => {
    const cfg = LEGACY_TEMPLATES[st.template] || LEGACY_TEMPLATES['Houses Both Sides'];
    const rows = Math.max(1, st.rows | 0 || 5);
    const colOff = Math.floor((COLS - cfg.cols) / 2);
    const sec = { id: st.id || uid(), name: st.name || `Street ${gi + 1}`, colorName: SECTION_COLORS[gi % 6], cells: [], lastModified: nowISO() };
    for (let r = 0; r < rows; r++) for (let c = 0; c < cfg.cols; c++) {
      const R = rowOffset + r, C = colOff + c;
      sec.cells.push([R, C]);
      if (cfg.road.includes(c) && !cfg.house.includes(c)) {
        out.blocks.push({ id: uid(), kind: 'road', row: R, col: C, houseName: '', colorName: 'purple', icon: '', decoration: null, residents: [], lastModified: nowISO() });
        placed.add(`${R},${C}`);
      }
    }
    out.sections.push(sec);
    for (const b of blocks) {
      if ((b.gridIndex | 0) !== gi) continue;
      if (b.row >= 0 && b.row < rows && cfg.house.includes(b.col | 0)) {
        const R = rowOffset + (b.row | 0), C = colOff + (b.col | 0);
        if (placed.has(`${R},${C}`)) { spill.push(b); continue; }
        placed.add(`${R},${C}`);
        out.blocks.push(legacyHouse(b, R, C));
      } else spill.push(b);
    }
    rowOffset += rows + 1;
  });
  for (const b of blocks) if (!(b.gridIndex >= 0 && b.gridIndex < streets.length)) spill.push(b);
  const total = Math.max(0, rowOffset - 1);          // rows used by the streets (without the trailing gap)
  const spillStart = total ? total + 1 : 0;          // leave one empty row before the spill
  let lastRow = total - 1;
  spill.forEach((b, i) => {
    const R = spillStart + Math.floor(i / COLS), C = i % COLS;
    out.blocks.push(legacyHouse(b, R, C));
    lastRow = R;
  });
  out.rows = Math.min(MAX_ROWS, Math.max(16, lastRow + 1 + 2));
  out.columns = COLS;
  return out;
}
function legacyHouse(b, R, C) {
  return {
    id: normId(b.id) || uid(), kind: 'house', row: R, col: C, houseName: b.houseName || '',
    colorName: COLORS.includes(b.colorName) ? b.colorName : 'purple', icon: b.icon || '🏠',
    decoration: b.decoration || null,
    residents: (b.residents || []).map((p) => normPerson({
      id: normId(p.id) || uid(), firstName: p.firstName, lastName: p.lastName,
      gender: p.gender, role: p.role, birthday: legacyDate(p.birthday), lineId: p.lineId,
      lastModified: p.lastModified,
    })),
    lastModified: b.lastModified || nowISO(),
  };
}
