// ===== The map screen =====
const ui = {
  edit: false, tool: null, moving: null, moveSrc: null,
  dismissedBirthday: false, dismissedSaveError: false,
};

function renderAll() {
  renderTop();
  renderBanners();
  renderMap();
  renderPalette();
  refreshModals();
}

function renderTop() {
  const n = houses().length;
  $('#count').textContent = n === 1 ? t('{0} home', n) : t('{0} homes', n);
  const eb = $('#btnEdit');
  eb.textContent = ui.edit ? t('Done') : '✏️ ' + t('Edit Map');
  eb.classList.toggle('on', ui.edit);
  $('#editNote').hidden = !ui.edit;
  $('#editNote').textContent = t('Edit Map · tap cells to change them');
  $('#count').hidden = ui.edit;
  $('#btnZoomOut').disabled = settings.zoom <= 0;
  $('#btnZoomIn').disabled = settings.zoom >= ZOOMS.length - 1;
  document.documentElement.lang = LANG;
}

function renderBanners() {
  const box = $('#banners');
  box.replaceChildren();
  if (!saveStatus.ok && !ui.dismissedSaveError) {
    box.appendChild(h('div', { class: 'banner err' },
      h('span', null, '⚠️ ' + t('Your latest change could not be saved: {0}', saveStatus.error || '')),
      h('button', { type: 'button', onclick: async () => { await doSave(); renderBanners(); } }, t('Try again')),
      h('button', { type: 'button', onclick: () => { ui.dismissedSaveError = true; renderBanners(); } }, '✕')));
  }
  if (ui.moving) {
    const b = blockById(ui.moving);
    box.appendChild(h('div', { class: 'banner move' },
      h('span', null, t('Tap an empty cell to move {0}', b ? b.houseName : '')),
      h('button', { type: 'button', onclick: () => { ui.moving = null; renderAll(); } }, t('Cancel'))));
  }
  if (!ui.dismissedBirthday && !ui.edit) {
    const soon = upcomingBirthdays(3).slice(0, 4);
    if (soon.length) {
      box.appendChild(h('div', { class: 'banner bday' },
        h('div', { class: 'bl' }, soon.map((x) => h('div', null,
          '🎂 ', x.days === 0 ? t('Today') : x.days === 1 ? t('Tomorrow') : t('In {0} days', x.days), ': ',
          h('b', null, fullName(x.person) || '?'), ` — ${placeLabel(x.block)} · ${t('turns {0}', x.turns)}`))),
        h('button', { type: 'button', onclick: () => { ui.dismissedBirthday = true; renderBanners(); } }, '✕')));
    }
  }
}

function baseCellPx() {
  const sc = $('#mapScroll');
  const avail = Math.max(240, (sc.clientWidth || window.innerWidth) - 32);
  return Math.min(104, Math.floor((avail - GAP * 5) / 6));
}
function cellPx() { return Math.max(22, Math.round(baseCellPx() * ZOOMS[settings.zoom])); }

function roadSVG(r, c) {
  const isRoad = (rr, cc) => { const b = blockAt(rr, cc); return b && b.kind === 'road'; };
  const U = isRoad(r - 1, c), D = isRoad(r + 1, c), L = isRoad(r, c - 1), R = isRoad(r, c + 1);
  const ns = 'http://www.w3.org/2000/svg';
  const svg = document.createElementNS(ns, 'svg');
  svg.setAttribute('viewBox', '0 0 100 100');
  svg.setAttribute('class', 'roadsvg');
  svg.setAttribute('aria-hidden', 'true');
  const add = (tag, attrs, cls) => { const e = document.createElementNS(ns, tag); for (const k in attrs) e.setAttribute(k, attrs[k]); if (cls) e.setAttribute('class', cls); svg.appendChild(e); };
  add('rect', { x: 0, y: 0, width: 100, height: 100, rx: 10 }, 'rd');
  const ext = 14;
  if (U) add('rect', { x: 0, y: -ext, width: 100, height: 50 + ext }, 'rd');
  if (D) add('rect', { x: 0, y: 50, width: 100, height: 50 + ext }, 'rd');
  if (L) add('rect', { x: -ext, y: 0, width: 50 + ext, height: 100 }, 'rd');
  if (R) add('rect', { x: 50, y: 0, width: 50 + ext, height: 100 }, 'rd');
  if (U && D && R && !L || false) { /* junction shapes are covered by the arms above */ }
  const cap = (x, y, w, hh) => add('rect', { x: x - w / 2, y: y - hh / 2, width: w, height: hh, rx: Math.min(w, hh) / 2 }, 'rdash');
  const horizOnly = (L || R) && !U && !D, vertOnly = (U || D) && !L && !R;
  if (horizOnly) { for (const x of [16, 50, 84]) cap(x, 50, 18, 7); }
  else if (vertOnly) { for (const y of [16, 50, 84]) cap(50, y, 7, 18); }
  else if (!U && !D && !L && !R) { add('circle', { cx: 50, cy: 50, r: 4.5 }, 'rdash'); }
  else {
    add('circle', { cx: 50, cy: 50, r: 4.5 }, 'rdash');
    if (U) cap(50, 24, 7, 18); if (D) cap(50, 76, 7, 18); if (L) cap(24, 50, 18, 7); if (R) cap(76, 50, 18, 7);
  }
  return svg;
}

function cellEl(r, c) {
  const b = blockAt(r, c);
  const sec = sectionAt(r, c);
  const cls = ['cell'];
  const attrs = { type: 'button', 'data-r': r, 'data-c': c };
  const kids = [];
  if (sec) cls.push('sec', 'sc-' + sec.colorName);
  if (!b) { cls.push('grass'); attrs['aria-label'] = t('Empty cell, row {0}, column {1}', r + 1, c + 1); }
  else if (b.kind === 'road') { cls.push('road'); attrs['aria-label'] = t('Road, row {0}, column {1}', r + 1, c + 1); kids.push(roadSVG(r, c)); }
  else if (b.kind === 'decoration') { cls.push('deco'); attrs['aria-label'] = t('Decoration {0}', b.icon); kids.push(h('span', { class: 'bigico' }, b.icon)); }
  else {
    cls.push('house', 'hc-' + b.colorName);
    const photo = photoOf(b.id);
    attrs['aria-label'] = `${b.houseName}, ${b.residents.length === 1 ? t('{0} resident', 1) : t('{0} residents', b.residents.length)}`;
    kids.push(photo ? h('img', { class: 'hph', src: photo, alt: '' }) : h('span', { class: 'ico' }, b.decoration || b.icon));
    kids.push(h('span', { class: 'nm' }, b.houseName));
    if (b.residents.length) kids.push(h('span', { class: 'cnt' }, `${b.residents.length} 👤`));
    if (houseHasBirthdaySoon(b)) kids.push(h('span', { class: 'cake', title: t('Birthday this week') }, '🎂'));
  }
  if (ui.moving && !b) cls.push('drop');
  if (ui.edit && ui.tool && ui.tool.type === 'move' && ui.moveSrc && !b) cls.push('drop');
  if ((ui.moving && b && b.id === ui.moving) || (ui.moveSrc && b && b.id === ui.moveSrc)) cls.push('lift');
  // section name chip on the top-left cell of each section
  if (sec) {
    const a = sectionAnchor(sec);
    if (a && a[0] === r && a[1] === c && sec.name) kids.push(h('span', { class: 'chip', 'data-sid': sec.id, style: { background: `var(--sc-${sec.colorName})` } }, sec.name));
  }
  return h('button', { ...attrs, class: cls.join(' ') }, kids);
}

function renderMap() {
  const map = $('#map');
  map.className = `map ${settings.grass}${ui.edit ? ' editing' : ''}`;
  map.style.setProperty('--cell', cellPx() + 'px');
  map.style.gridTemplateColumns = `repeat(${S.columns}, var(--cell))`;
  const frag = document.createDocumentFragment();
  for (let r = 0; r < S.rows; r++) for (let c = 0; c < S.columns; c++) frag.appendChild(cellEl(r, c));
  map.replaceChildren(frag);
  // row / column buttons while editing
  const gt = $('#gridTools');
  gt.replaceChildren();
  gt.hidden = !ui.edit;
  if (ui.edit) {
    gt.append(
      h('button', { type: 'button', onclick: () => addRow(), disabled: S.rows >= MAX_ROWS }, '＋ ' + t('Row')),
      h('button', { type: 'button', onclick: () => removeRow(), disabled: !canRemoveRow() }, '－ ' + t('Row')),
      h('button', { type: 'button', onclick: () => addColumn(), disabled: S.columns >= MAX_COLS }, '＋ ' + t('Column')),
      h('button', { type: 'button', onclick: () => removeColumn(), disabled: !canRemoveColumn() }, '－ ' + t('Column')));
  }
  $('#mapScroll').classList.toggle('padpal', ui.edit);
}

// ----- tapping and painting -----
let suppressClick = false;
function doUndo() { if (undo()) { renderAll(); toast(t('Undone')); } }

function normalTap(r, c) {
  const b = blockAt(r, c);
  if (ui.moving) {
    if (!b) { const id = ui.moving; ui.moving = null; moveBlock(id, r, c); toast(t('Moved'), { action: { label: t('Undo'), fn: doUndo } }); }
    else if (b.id === ui.moving) { ui.moving = null; renderAll(); }
    return;
  }
  if (!b) {
    createHouseAt(r, c);
    toast(t('House added'), { action: { label: t('Undo'), fn: doUndo }, ms: 3000 });
    return;
  }
  if (b.kind === 'house') openHouseSheet(b.id);
}

function editTap(r, c) {
  const tool = ui.tool;
  if (!tool) { toast(t('Pick a cell type below first.')); return; }
  const cur = blockAt(r, c);
  if (tool.type === 'move') {
    if (!ui.moveSrc) { if (cur) { ui.moveSrc = cur.id; renderAll(); } else toast(t('Tap the cell you want to move first.')); return; }
    if (!cur) { const id = ui.moveSrc; ui.moveSrc = null; moveBlock(id, r, c); }
    else if (cur.id === ui.moveSrc) { ui.moveSrc = null; renderAll(); }
    else toast(t('Pick an empty cell.'));
    return;
  }
  const losing = cur && cur.kind === 'house' && cur.residents.length && tool.type !== 'house' && tool.type !== 'section' ? cur : null;
  const changed = paintCell(r, c, tool);
  if (changed && losing) toast(t('{0} was removed together with its {1} people.', losing.houseName, losing.residents.length), { action: { label: t('Undo'), fn: doUndo }, ms: 5000 });
}

function onMapClick(e) {
  const chip = e.target.closest('.chip');
  if (chip && ui.edit) { openSectionEditor(chip.dataset.sid); return; }
  const cell = e.target.closest('.cell');
  if (!cell) return;
  if (suppressClick) { suppressClick = false; return; }
  const r = +cell.dataset.r, c = +cell.dataset.c;
  if (ui.edit) editTap(r, c); else normalTap(r, c);
}

// With a mouse you can also drag across cells to paint a whole stroke (one Undo for the stroke).
let stroking = false, lastStrokeCell = null;
function strokePaint(el) {
  const cell = el && el.closest && el.closest('.cell');
  if (!cell) return;
  const r = +cell.dataset.r, c = +cell.dataset.c, key = r + ',' + c;
  if (key === lastStrokeCell) return;
  lastStrokeCell = key;
  paintCell(r, c, ui.tool);
}
function setupStrokes() {
  const map = $('#map');
  map.addEventListener('pointerdown', (e) => {
    if (!ui.edit || !ui.tool || ui.tool.type === 'move' || e.pointerType !== 'mouse' || e.button !== 0) return;
    if (e.target.closest('.chip')) return;
    stroking = true; lastStrokeCell = null; suppressClick = true;
    beginStroke();
    const cell = e.target.closest('.cell');
    if (cell) {
      const cur = blockAt(+cell.dataset.r, +cell.dataset.c);
      if (cur && cur.kind === 'house' && cur.residents.length && ui.tool.type !== 'house' && ui.tool.type !== 'section') {
        // a single click on a house with people: let the normal click handler warn with an Undo toast
        stroking = false; suppressClick = false; endStroke(); return;
      }
    }
    strokePaint(e.target);
  });
  map.addEventListener('pointermove', (e) => {
    if (!stroking || !(e.buttons & 1)) return;
    strokePaint(document.elementFromPoint(e.clientX, e.clientY));
  });
  const end = () => { if (stroking) { stroking = false; endStroke(); setTimeout(() => { suppressClick = false; }, 60); } };
  window.addEventListener('pointerup', end);
  window.addEventListener('pointercancel', end);
}

// ----- the Edit Map palette -----
function setTool(tool) { ui.tool = tool; ui.moveSrc = null; renderAll(); }
function toolIs(type, extra) { return ui.tool && ui.tool.type === type && (extra === undefined || ui.tool.emoji === extra); }

function renderPalette() {
  const p = $('#palette');
  p.replaceChildren();
  p.hidden = !ui.edit;
  if (!ui.edit) return;
  const chip = (key, label, selected, onclick, content) => h('button', { type: 'button', class: 'pchip' + (selected ? ' sel' : ''), 'aria-pressed': selected ? 'true' : 'false', onclick },
    h('span', { class: 'pc ' + key }, content), h('span', { class: 'pl' }, label));
  const chips = [
    chip('grass', t('Grass'), toolIs('grass'), () => setTool({ type: 'grass' }), ''),
    chip('road', t('Road'), toolIs('road'), () => setTool({ type: 'road' }), h('i')),
    chip('house', t('House'), toolIs('house'), () => setTool({ type: 'house' }), '🏠'),
    ...settings.favorites.map((e) => chip('em', '', toolIs('emoji', e), () => setTool({ type: 'emoji', emoji: e }), e)),
    chip('em', t('More'), false, () => openEmojiPicker((em) => { rememberEmoji(em); setTool({ type: 'emoji', emoji: em }); }), '…'),
    chip('sec', t('Section'), toolIs('section'), () => setTool({ type: 'section', sectionId: ui.tool && ui.tool.sectionId || (S.sections[0] && S.sections[0].id) || null }), 'A'),
    chip('mv', t('Move'), toolIs('move'), () => setTool({ type: 'move' }), '✥'),
  ];
  // favorites carry their own short caption
  const labels = [t('Grass'), t('Road'), t('House')];
  const row = h('div', { class: 'chips' }, chips);
  const head = h('div', { class: 'phead' },
    h('b', null, t('Cell type')),
    h('button', { type: 'button', class: 'undo', disabled: !canUndo(), onclick: doUndo }, '↶ ' + t('Undo')));
  p.append(h('div', { class: 'grip' }), head, row);
  if (settings.recent.length) {
    p.append(h('div', { class: 'recent' }, h('span', { class: 'rl' }, t('Recent')),
      settings.recent.map((e) => h('button', { type: 'button', class: 'rchip' + (toolIs('emoji', e) ? ' sel' : ''), onclick: () => setTool({ type: 'emoji', emoji: e }) }, e))));
  }
  if (toolIs('section')) {
    const cur = ui.tool.sectionId;
    p.append(h('div', { class: 'secrow' },
      h('button', { type: 'button', class: 'spill' + (!cur ? ' sel' : ''), onclick: () => setTool({ type: 'section', sectionId: null }) }, t('No section')),
      S.sections.map((s) => h('button', { type: 'button', class: 'spill' + (cur === s.id ? ' sel' : ''), style: { '--pc': `var(--sc-${s.colorName})` }, onclick: () => setTool({ type: 'section', sectionId: s.id }) }, s.name || t('Section')),),
      h('button', { type: 'button', class: 'spill add', onclick: () => openSectionEditor(null) }, '＋ ' + t('New section')),
      cur ? h('button', { type: 'button', class: 'spill', onclick: () => openSectionEditor(cur) }, '✏️') : null));
  }
  p.append(h('div', { class: 'phint' }, !ui.tool ? t('Pick a type, then tap cells.') :
    ui.tool.type === 'move' ? (ui.moveSrc ? t('Now tap an empty cell.') : t('Tap a cell, then an empty cell.')) :
    ui.tool.type === 'section' ? t('Tap cells to put them in the chosen section.') :
    t('Tap cells to paint. Painting over a house removes it and its people (Undo brings it back).')));
}
function rememberEmoji(em) {
  settings.recent = [em, ...settings.recent.filter((x) => x !== em)].slice(0, 10);
  saveSettings();
}

function setZoom(i) {
  settings.zoom = Math.max(0, Math.min(ZOOMS.length - 1, i));
  saveSettings();
  renderMap(); renderTop();
}
