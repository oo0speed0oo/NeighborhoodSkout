// ===== CSV (for Excel, Numbers, Google Sheets) =====
const CSV_HEADER = ['Kind', 'Section', 'HouseName', 'Row', 'Col', 'Color', 'Icon', 'Decoration',
  'FirstName', 'LastName', 'Gender', 'Role', 'Birthday', 'LineID', 'Phone', 'Email', 'Notes',
  'HouseID', 'PersonID', 'HouseLastModified', 'PersonLastModified'];

function csvEscape(v) {
  const s = v === null || v === undefined ? '' : String(v);
  return /[",\r\n]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}
function csvParse(text) {
  if (text.charCodeAt(0) === 0xFEFF) text = text.slice(1);
  const rows = []; let row = [], cur = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const ch = text[i];
    if (q) {
      if (ch === '"') { if (text[i + 1] === '"') { cur += '"'; i++; } else q = false; }
      else cur += ch;
    } else if (ch === '"') q = true;
    else if (ch === ',') { row.push(cur); cur = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && text[i + 1] === '\n') i++;
      row.push(cur); cur = ''; rows.push(row); row = [];
    } else cur += ch;
  }
  if (cur !== '' || row.length) { row.push(cur); rows.push(row); }
  return rows;
}
// Read a file as UTF-8, or Shift-JIS if it is not valid UTF-8 (Excel's plain "CSV" on a Japanese PC).
function decodeBytes(buf) {
  const bytes = new Uint8Array(buf);
  try { return { text: new TextDecoder('utf-8', { fatal: true }).decode(bytes), encoding: 'UTF-8' }; } catch (e) { /* next */ }
  for (const enc of ['shift_jis', 'windows-1252']) {
    try { return { text: new TextDecoder(enc, { fatal: true }).decode(bytes), encoding: enc === 'shift_jis' ? 'Shift-JIS' : 'Windows-1252' }; } catch (e) { /* next */ }
  }
  return { text: new TextDecoder('utf-8').decode(bytes), encoding: 'UTF-8 (some characters may be wrong)' };
}

function buildCSV() {
  const lines = [CSV_HEADER.join(',')];
  const sorted = [...S.blocks].sort((a, b) => a.row - b.row || a.col - b.col);
  for (const b of sorted) {
    const sec = sectionOfBlock(b);
    const base = [b.kind === 'house' ? 'House' : b.kind === 'road' ? 'Road' : 'Decoration', sec ? sec.name : '',
      b.kind === 'house' ? b.houseName : '', b.row, b.col, b.kind === 'house' ? b.colorName : '',
      b.icon || '', b.decoration || ''];
    const ids = [b.id];
    if (b.kind !== 'house' || !b.residents.length) {
      lines.push([...base, '', '', '', '', '', '', '', '', '', b.id, '', b.lastModified, ''].map(csvEscape).join(','));
    } else {
      for (const p of b.residents) {
        lines.push([...base, p.firstName, p.lastName, p.gender, p.role, p.birthday, p.lineId, p.phone, p.email, p.notes,
          b.id, p.id, b.lastModified, p.lastModified].map(csvEscape).join(','));
      }
    }
  }
  return '﻿' + lines.join('\r\n') + '\r\n';
}

// ----- detecting what kind of file this is -----
function detectCSVKind(rows) {
  const head = rows.slice(0, 30);
  for (const r of head) {
    const first = (r[0] || '').trim().replace(/^﻿/, '');
    if (first === 'Kind' || (r.map(lc).includes('kind') && r.map(lc).includes('housename'))) return 'grid';
  }
  for (const r of head) { const f = (r[0] || '').trim(); if (f === 'HouseID' || f === 'HouseName' || f === '#STREET') return 'legacy'; }
  return 'unknown';
}

// Old street-based CSV (both the simple and the UUID flavors) -> same shape as the old JSON store.
function parseLegacyCSV(rows) {
  const streets = []; const blocksMap = new Map();
  let mode = null; let hdr = null;
  const nonEmpty = rows.filter((r) => r.some((c) => String(c).trim() !== ''));
  for (const r of nonEmpty) {
    const f = (r[0] || '').trim();
    if (f === '#STREET') {
      // simple: #STREET,Name,Template,Rows   |  v2: #STREET,StreetID,Name,Template,Rows,LastModified
      if (lc(r[1]) === 'name' || lc(r[1]) === 'streetid') continue;
      const isV2 = /^[0-9a-f]{8}-[0-9a-f]{4}-/i.test((r[1] || '').trim());
      streets.push(isV2 ? { id: normId(r[1]), name: r[2], template: r[3], rows: parseInt(r[4], 10) || 5 }
        : { id: uid(), name: r[1], template: r[2], rows: parseInt(r[3], 10) || 5 });
      continue;
    }
    if (f === 'HouseID') { mode = 'v2'; hdr = r; continue; }
    if (f === 'HouseName') { mode = 'simple'; hdr = r; continue; }
    if (!mode) continue;
    let b, p = null;
    if (mode === 'v2') {
      // HouseID,HouseName,StreetID,StreetName,GridIndex,Row,Col,ColorName,Icon,Decoration,PersonID,FirstName,LastName,Gender,Role,Birthday,LineID,HouseLast,PersonLast
      const id = normId(r[0]); if (!id) continue;
      b = blocksMap.get(id) || { id, houseName: r[1], gridIndex: parseInt(r[4], 10) || 0, row: parseInt(r[5], 10) || 0, col: parseInt(r[6], 10) || 0, colorName: r[7], icon: r[8], decoration: r[9] || null, residents: [] };
      blocksMap.set(id, b);
      if ((r[11] || '').trim() || (r[12] || '').trim()) p = { id: normId(r[10]) || uid(), firstName: r[11], lastName: r[12], gender: r[13], role: r[14], birthday: r[15], lineId: r[16] };
    } else {
      // HouseName,GridIndex,Row,Col,ColorName,Icon,FirstName,LastName,Gender,Role,Birthday,LineID
      const gi = parseInt(r[1], 10) || 0, ro = parseInt(r[2], 10) || 0, co = parseInt(r[3], 10) || 0;
      const key = `${gi}-${ro}-${co}`;
      b = blocksMap.get(key) || { id: uid(), houseName: r[0], gridIndex: gi, row: ro, col: co, colorName: r[4], icon: r[5], decoration: null, residents: [] };
      blocksMap.set(key, b);
      if ((r[6] || '').trim() || (r[7] || '').trim()) p = { id: uid(), firstName: r[6], lastName: r[7], gender: r[8], role: r[9], birthday: r[10], lineId: r[11] };
    }
    if (p) { p.birthday = parseDateLoose(p.birthday) || ''; b.residents.push(p); }
  }
  const sts = streets.length ? streets : [
    { id: uid(), name: 'Street 1', template: 'Houses Both Sides', rows: 5 },
    { id: uid(), name: 'Street 2', template: 'Houses Right Side', rows: 5 },
    { id: uid(), name: 'Street 3', template: 'Houses Both Sides', rows: 5 }];
  return { streets: sts, blocks: [...blocksMap.values()] };
}

// ----- the new grid CSV: plan an import and describe every change before applying it -----
function mapRole(v) {
  const s = lc(v);
  if (!s) return null;
  if (['grandparent', 'grandparents', '祖父母', 'おじいちゃん', 'おばあちゃん', '祖父', '祖母'].includes(s)) return 'Grandparent';
  if (['parent', 'parents', '親', '父', '母', '両親', '保護者'].includes(s)) return 'Parent';
  if (['child', 'children', 'kid', '子', '子供', '子ども'].includes(s)) return 'Child';
  if (['other', 'others', 'その他', '他'].includes(s)) return 'Other';
  return undefined;
}
function mapGender(v) {
  const s = lc(v);
  if (!s) return null;
  if (['male', 'm', 'man', '男', '男性'].includes(s)) return 'Male';
  if (['female', 'f', 'woman', '女', '女性'].includes(s)) return 'Female';
  if (['other', 'o', 'その他', '他'].includes(s)) return 'Other';
  return undefined;
}

// mode 'merge': keep everything not in the file. mode 'replace': the file becomes the whole map.
function planCSVImport(rows, mode) {
  const plan = { state: null, changes: [], errors: [], warnings: [], counts: { newHouses: 0, updatedHouses: 0, newPeople: 0, updatedPeople: 0, cells: 0 } };
  const addChange = (kind, text) => plan.changes.push({ kind, text });
  const nonEmpty = [];
  rows.forEach((r, i) => { if (r.some((c) => String(c).trim() !== '')) nonEmpty.push({ r, n: i + 1 }); });
  if (!nonEmpty.length) { plan.errors.push({ row: 0, msg: t('The file is empty.') }); return plan; }
  const headerRec = nonEmpty.find((x) => x.r.map(lc).includes('kind') || x.r.map(lc).includes('housename'));
  if (!headerRec) { plan.errors.push({ row: 0, msg: t('No header row found. The first row must contain column names such as HouseName.') }); return plan; }
  const hdr = headerRec.r.map((s) => lc(s).replace(/^﻿/, ''));
  const col = (name) => hdr.indexOf(lc(name));
  const has = (name) => col(name) >= 0;
  const get = (rec, name) => { const i = col(name); return i >= 0 ? String(rec.r[i] === undefined ? '' : rec.r[i]).trim() : ''; };

  // working copy
  const base = mode === 'replace' ? { ...blankState(), columns: S.columns, rows: S.rows } : normalizeState(clone(S));
  const oldSections = S.sections;
  if (mode === 'replace') base.sections = [];
  const byId = new Map(base.blocks.map((b) => [normId(b.id), b]));
  const houseByName = new Map();
  for (const b of base.blocks) if (b.kind === 'house') { const k = lc(b.houseName); houseByName.set(k, houseByName.has(k) ? null : b); }
  const sectionByName = (name) => base.sections.find((s) => lc(s.name) === lc(name));
  const getSection = (name) => {
    let sec = sectionByName(name);
    if (!sec) {
      const old = oldSections.find((s) => lc(s.name) === lc(name));
      const used = base.sections.map((s) => s.colorName);
      const color = old ? old.colorName : (SECTION_COLORS.find((c) => !used.includes(c)) || SECTION_COLORS[base.sections.length % SECTION_COLORS.length]);
      sec = { id: old ? old.id : uid(), name, colorName: color, cells: [], lastModified: nowISO() };
      base.sections.push(sec);
      addChange('new', t('New section: {0}', name));
    }
    return sec;
  };

  const bodyRecs = nonEmpty.filter((x) => x !== headerRec && nonEmpty.indexOf(x) > nonEmpty.indexOf(headerRec));
  const groups = new Map();      // house key -> {recs, key}
  const cellOps = [];            // roads and decorations
  for (const rec of bodyRecs) {
    const kindRaw = lc(get(rec, 'Kind'));
    const kind = !kindRaw ? 'house' : (kindRaw.startsWith('road') || kindRaw === '道' || kindRaw === '道路') ? 'road'
      : (kindRaw.startsWith('deco') || kindRaw === '装飾') ? 'decoration' : (kindRaw === 'house' || kindRaw === '家') ? 'house' : null;
    if (!kind) { plan.errors.push({ row: rec.n, msg: t('Unknown Kind "{0}". Use House, Road or Decoration.', get(rec, 'Kind')) }); continue; }
    if (kind === 'house') {
      const id = normId(get(rec, 'HouseID'));
      const name = get(rec, 'HouseName');
      if (!id && !name) { plan.errors.push({ row: rec.n, msg: t('A house row needs a HouseName or a HouseID.') }); continue; }
      const key = id ? 'id:' + id : 'name:' + lc(name);
      if (!groups.has(key)) groups.set(key, { id, name, recs: [] });
      groups.get(key).recs.push(rec);
    } else {
      const r = parseInt(get(rec, 'Row'), 10), c = parseInt(get(rec, 'Col'), 10);
      if (!(r >= 0) || !(c >= 0) || r >= MAX_ROWS || c >= MAX_COLS) { plan.errors.push({ row: rec.n, msg: t('{0} rows need valid Row and Col numbers.', kind === 'road' ? t('Road') : t('Decoration')) }); continue; }
      cellOps.push({ rec, kind, r, c });
    }
  }

  // houses ----------------------------------------------------------
  const toPlace = [];            // {block, r, c, wanted:boolean}
  for (const g of groups.values()) {
    const first = g.recs[0];
    let block = (g.id && byId.get(g.id)) || null;
    if (!block && !g.id) { const m = houseByName.get(lc(g.name)); block = m || null; }
    const name = g.recs.map((x) => get(x, 'HouseName')).find(Boolean) || '';
    const rr = parseInt(get(first, 'Row'), 10), cc = parseInt(get(first, 'Col'), 10);
    const posOk = rr >= 0 && cc >= 0 && rr < MAX_ROWS && cc < MAX_COLS;
    const rawPos = get(first, 'Row') !== '' || get(first, 'Col') !== '';
    if (rawPos && !posOk) plan.errors.push({ row: first.n, msg: t('Row/Col "{0}/{1}" is not a valid position. The house keeps its place.', get(first, 'Row'), get(first, 'Col')) });
    const color = lc(get(first, 'Color')); const icon = get(first, 'Icon'); const deco = get(first, 'Decoration');
    const secName = get(first, 'Section');
    let isNew = false;
    if (!block) {
      isNew = true;
      const hsCount = base.blocks.filter((b) => b.kind === 'house').length;
      block = {
        id: g.id || uid(), kind: 'house', row: -1, col: -1, houseName: name || t('House {0}', hsCount + 1),
        colorName: COLORS.includes(color) ? color : COLORS[hsCount % 8], icon: icon || HOUSE_ICONS[hsCount % 8],
        decoration: deco || null, residents: [], lastModified: nowISO(),
      };
      base.blocks.push(block); byId.set(normId(block.id), block);
      plan.counts.newHouses++;
      addChange('new', t('New house: {0}', block.houseName));
    } else {
      const diffs = [];
      if (name && name !== block.houseName) { diffs.push(t('name "{0}" → "{1}"', block.houseName, name)); block.houseName = name; }
      if (color && COLORS.includes(color) && color !== block.colorName) { diffs.push(t('color {0} → {1}', block.colorName, color)); block.colorName = color; }
      if (icon && icon !== block.icon) { diffs.push(t('icon {0} → {1}', block.icon, icon)); block.icon = icon; }
      if (has('Decoration') && (deco || '') !== (block.decoration || '')) { diffs.push(t('decoration {0} → {1}', block.decoration || '–', deco || '–')); block.decoration = deco || null; }
      if (diffs.length) { block.lastModified = nowISO(); plan.counts.updatedHouses++; addChange('update', `${block.houseName}: ${diffs.join(', ')}`); }
    }
    block.__sec = has('Section') ? secName : undefined;
    block.__want = posOk ? [rr, cc] : null;
    toPlace.push(block);

    // people
    for (const rec of g.recs) {
      const fn = get(rec, 'FirstName'), ln = get(rec, 'LastName');
      if (!fn && !ln) continue;
      const bdRaw = get(rec, 'Birthday');
      const bd = parseDateLoose(bdRaw);
      if (bdRaw && bd === null) { plan.errors.push({ row: rec.n, msg: t('Birthday "{0}" is not a date I understand (use 2024-05-03). {1} was not imported.', bdRaw, `${fn} ${ln}`.trim()) }); continue; }
      const genderRaw = get(rec, 'Gender'), roleRaw = get(rec, 'Role');
      const gender = mapGender(genderRaw), role = mapRole(roleRaw);
      if (gender === undefined) { plan.errors.push({ row: rec.n, msg: t('Gender "{0}" is not understood (Male, Female or Other). {1} was not imported.', genderRaw, `${fn} ${ln}`.trim()) }); continue; }
      if (role === undefined) { plan.errors.push({ row: rec.n, msg: t('Role "{0}" is not understood (Grandparent, Parent, Child or Other). {1} was not imported.', roleRaw, `${fn} ${ln}`.trim()) }); continue; }
      const pid = normId(get(rec, 'PersonID'));
      let person = pid ? block.residents.find((p) => normId(p.id) === pid) : null;
      if (!person) person = block.residents.find((p) => lc(p.firstName) === lc(fn) && lc(p.lastName) === lc(ln) && (!pid || true)) || null;
      const vals = { firstName: fn, lastName: ln, birthday: bd };
      if (gender) vals.gender = gender;
      if (role) vals.role = role;
      for (const [k, colName] of [['lineId', 'LineID'], ['phone', 'Phone'], ['email', 'Email'], ['notes', 'Notes']]) if (has(colName)) vals[k] = get(rec, colName);
      if (!has('Birthday')) delete vals.birthday;
      if (!person) {
        person = normPerson({ id: pid || uid(), gender: gender || 'Other', role: role || 'Other', birthday: '', ...vals });
        block.residents.push(person);
        plan.counts.newPeople++;
        addChange('new', t('New person: {0} ({1})', `${fn} ${ln}`.trim(), block.houseName));
      } else {
        const diffs = [];
        const labels = { firstName: t('first name'), lastName: t('last name'), gender: t('gender'), role: t('role'), birthday: t('birthday'), lineId: t('LINE ID'), phone: t('phone'), email: t('email'), notes: t('notes') };
        for (const [k, v] of Object.entries(vals)) {
          if ((person[k] || '') !== (v || '')) { diffs.push(`${labels[k]} ${person[k] || '–'} → ${v || '–'}`); person[k] = v || ''; }
        }
        if (diffs.length) { person.lastModified = nowISO(); plan.counts.updatedPeople++; addChange('update', `${`${person.firstName} ${person.lastName}`.trim()}: ${diffs.join(', ')}`); }
      }
    }
  }

  // roads and decorations -------------------------------------------
  const cellsToSet = [];
  for (const op of cellOps) {
    const sec = has('Section') ? get(op.rec, 'Section') : undefined;
    if (op.kind === 'road') cellsToSet.push({ kind: 'road', r: op.r, c: op.c, sec, n: op.rec.n });
    else {
      const em = firstEmoji(get(op.rec, 'Icon')) || firstEmoji(get(op.rec, 'Decoration'));
      if (!em) { plan.errors.push({ row: op.rec.n, msg: t('Decoration rows need an emoji in the Icon column.') }); continue; }
      cellsToSet.push({ kind: 'decoration', r: op.r, c: op.c, emoji: em, sec, n: op.rec.n });
    }
  }

  // placement: move/place houses, then set road and decoration cells --------------
  const moving = toPlace.filter((b) => b.__want);
  const unplaced = toPlace.filter((b) => !b.__want && b.row < 0);
  const fixed = base.blocks.filter((b) => !toPlace.includes(b));
  const taken = new Map(fixed.map((b) => [`${b.row},${b.col}`, b]));
  for (const b of toPlace) if (!b.__want && b.row >= 0) taken.set(`${b.row},${b.col}`, b);
  const growTo = (r, c) => { if (r >= base.rows) base.rows = Math.min(MAX_ROWS, r + 1); if (c >= base.columns) base.columns = Math.min(MAX_COLS, c + 1); };
  const emptySpot = () => {
    for (let r = 0; r < MAX_ROWS; r++) for (let c = 0; c < Math.max(6, base.columns); c++) {
      if (!taken.has(`${r},${c}`) && !cellsToSet.some((x) => x.r === r && x.c === c)) { growTo(r, c); return [r, c]; }
    }
    return [base.rows, 0];
  };
  // cells claimed by roads/decorations in the file win over existing roads/decorations, but not over houses
  const claimed = new Set();
  for (const op of cellsToSet) {
    const k = `${op.r},${op.c}`;
    const cur = taken.get(k);
    if (cur && cur.kind === 'house') { plan.errors.push({ row: op.n, msg: t('Cell row {0}, col {1} is already a house ({2}), so the {3} was skipped.', op.r, op.c, cur.houseName, op.kind === 'road' ? t('road') : t('decoration')) }); op.skip = true; continue; }
    if (cur && cur.kind === op.kind && (op.kind === 'road' || cur.icon === op.emoji)) { op.skip = true; op.same = true; claimed.add(k); continue; }
    if (cur) { base.blocks = base.blocks.filter((b) => b !== cur); taken.delete(k); }
    claimed.add(k);
  }
  for (const b of moving) {
    const [r, c] = b.__want; const k = `${r},${c}`;
    const wasAt = b.row >= 0 ? `${b.row},${b.col}` : null;
    let occ = taken.get(k);
    if (occ && occ !== b && !claimed.has(k) && occ.kind !== 'house') { base.blocks = base.blocks.filter((x) => x !== occ); taken.delete(k); occ = null; }
    if ((occ && occ !== b) || claimed.has(k)) {
      const [er, ec] = emptySpot();
      plan.warnings.push(t('{0} wanted row {1}, col {2}, but that cell is taken. It was put at row {3}, col {4}.', b.houseName, r, c, er, ec));
      if (wasAt) taken.delete(wasAt);
      b.row = er; b.col = ec; taken.set(`${er},${ec}`, b);
    } else {
      if (wasAt && wasAt !== k) { taken.delete(wasAt); addChange('update', t('{0} moved to row {1}, col {2}', b.houseName, r, c)); }
      growTo(r, c); b.row = r; b.col = c; taken.set(k, b);
    }
  }
  for (const b of unplaced) { const [er, ec] = emptySpot(); b.row = er; b.col = ec; taken.set(`${er},${ec}`, b); }
  for (const op of cellsToSet) {
    if (op.skip) continue;
    growTo(op.r, op.c);
    const blk = { id: uid(), kind: op.kind, row: op.r, col: op.c, houseName: '', colorName: 'purple', icon: op.kind === 'decoration' ? op.emoji : '', decoration: null, residents: [], lastModified: nowISO() };
    base.blocks.push(blk); taken.set(`${op.r},${op.c}`, blk); plan.counts.cells++;
  }
  if (plan.counts.cells) addChange('new', t('{0} road/decoration cells set', plan.counts.cells));

  // sections --------------------------------------------------------
  const setSec = (r, c, name) => {
    for (const s of base.sections) { const i = s.cells.findIndex((p) => p[0] === r && p[1] === c); if (i >= 0 && lc(s.name) !== lc(name)) s.cells.splice(i, 1); }
    if (name) { const s = getSection(name); if (!s.cells.some((p) => p[0] === r && p[1] === c)) s.cells.push([r, c]); }
  };
  for (const b of toPlace) if (b.__sec !== undefined) setSec(b.row, b.col, b.__sec);
  for (const op of cellsToSet) if ((!op.skip || op.same) && op.sec !== undefined) setSec(op.r, op.c, op.sec);
  for (const b of base.blocks) { delete b.__sec; delete b.__want; }
  base.sections = base.sections.filter((s) => s.cells.length || mode === 'merge');

  plan.state = normalizeState(base);
  return plan;
}
