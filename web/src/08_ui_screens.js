// ===== Screens: house menu, residents, forms, settings, birthdays, import =====
const fmtMD = (ymd) => {
  const { m, d } = splitYMD(ymd);
  return new Date(2000, m - 1, d).toLocaleDateString(LANG === 'ja' ? 'ja-JP' : 'en-US', { month: 'short', day: 'numeric' });
};
const fmtDate = (ymd) => {
  const { y, m, d } = splitYMD(ymd);
  return new Date(y, m - 1, d).toLocaleDateString(LANG === 'ja' ? 'ja-JP' : 'en-US', { year: 'numeric', month: 'short', day: 'numeric' });
};
const fmtStamp = (iso) => new Date(iso).toLocaleString(LANG === 'ja' ? 'ja-JP' : 'en-US', { dateStyle: 'medium', timeStyle: 'short' });
const ROLE_PLURAL = { Grandparent: 'Grandparents', Parent: 'Parents', Child: 'Children', Other: 'Others' };
const residentsText = (n) => (n === 1 ? t('{0} resident', 1) : t('{0} residents', n));

// ----- the menu shown when you tap a house -----
function openHouseSheet(id) {
  const b = blockById(id);
  if (!b) return;
  const sec = sectionOfBlock(b);
  const n = b.residents.length;
  const lineCount = b.residents.filter((p) => p.lineId).length;
  openSheet(b.houseName, [sec && sec.name, n ? residentsText(n) : t('No residents yet')].filter(Boolean).join(' · '), [
    { label: '👥 ' + t('Residents'), onClick: () => openResidents(id) },
    { label: '💬 ' + t('Message on LINE'), onClick: () => openLineList(id), hidden: !lineCount },
    { label: t('Move'), onClick: () => { ui.moving = id; renderAll(); } },
    { label: '✏️ ' + t('Edit House'), onClick: () => openHouseEdit(id) },
    { label: t('Delete'), danger: true, onClick: () => { const name = b.houseName; deleteBlock(id); toast(t('{0} deleted.', name), { action: { label: t('Undo'), fn: doUndo }, ms: 6000 }); } },
  ]);
}

// ----- residents -----
function openResidents(id) {
  openModal({
    title: () => { const b = blockById(id); return b ? b.houseName : ''; },
    right: () => h('button', { class: 'mbtn strong', type: 'button', onclick: () => openPersonForm(id, null) }, '＋ ' + t('Add')),
    render(body, m) {
      const b = blockById(id);
      if (!b) { m.close(); return; }
      const photo = photoOf(b.id);
      if (photo) body.appendChild(h('img', { class: 'housephoto', src: photo, alt: '' }));
      if (!b.residents.length) {
        body.appendChild(h('div', { class: 'empty' }, h('div', { class: 'big' }, '👪'), h('div', null, t('No residents yet')), h('button', { class: 'primary', type: 'button', onclick: () => openPersonForm(id, null) }, '＋ ' + t('Add a resident'))));
        return;
      }
      for (const role of ROLES) {
        const list = b.residents.filter((p) => p.role === role);
        if (!list.length) continue;
        body.appendChild(h('div', { class: 'grouphead' }, `${ROLE_ICON[role]} ${t(ROLE_PLURAL[role])}`));
        list.forEach((p) => body.appendChild(personRow(id, p)));
      }
    },
  });
}
function personRow(houseId, p) {
  const age = ageOn(p);
  const nb = nextBirthday(p);
  const sub = [t(p.role), age !== null ? t('{0} yrs', age) : null, p.birthday ? '🎂 ' + fmtMD(p.birthday) : null].filter(Boolean).join(' · ');
  const stop = (fn) => (e) => { e.stopPropagation(); fn(e); };
  return h('div', { class: 'prow', role: 'button', tabindex: 0, onclick: () => openPersonForm(houseId, p.id), onkeydown: (e) => { if (e.key === 'Enter') openPersonForm(houseId, p.id); } },
    avatar(p, 46),
    h('div', { class: 'pmain' },
      h('div', { class: 'pname' }, fullName(p) || '?'),
      h('div', { class: 'psub' }, sub),
      nb && nb.days <= 14 ? h('div', { class: 'pbday' }, nb.days === 0 ? t('🎂 Birthday today!') : t('🎂 Birthday in {0} days', nb.days)) : null),
    h('div', { class: 'pbtns' },
      p.lineId ? h('button', { type: 'button', class: 'linebtn', 'aria-label': t('Message on LINE'), onclick: stop(() => openLine(p.lineId)) }, 'LINE') : null,
      p.phone ? h('a', { class: 'iconbtn', href: 'tel:' + p.phone.replace(/[^\d+]/g, ''), 'aria-label': t('Call'), onclick: (e) => e.stopPropagation() }, '📞') : null,
      p.email ? h('a', { class: 'iconbtn', href: 'mailto:' + p.email, 'aria-label': t('Email'), onclick: (e) => e.stopPropagation() }, '✉️') : null));
}

function openPersonForm(houseId, personId) {
  const b = blockById(houseId);
  if (!b) return;
  const existing = personId ? b.residents.find((p) => p.id === personId) : null;
  const d = existing ? clone(existing) : blankPerson();
  openModal({
    title: existing ? (fullName(d) || t('Resident')) : t('New resident'),
    live: false, back: t('Back'),
    render(body, m) {
      const avatarSlot = h('div', { class: 'avslot' }, avatar(d, 72));
      const refreshAvatar = () => avatarSlot.replaceChildren(avatar(d, 72));
      const inp = (key, props = {}) => h('input', { class: 'input', value: d[key] || '', oninput: (e) => { d[key] = e.target.value; }, ...props });
      body.append(
        h('div', { class: 'photorow' }, avatarSlot, h('div', { class: 'pbtnrow' },
          h('button', { type: 'button', class: 'ghost', onclick: async () => {
            const f = await pickFile('image/*'); if (!f) return;
            try { await setPhoto(d.id, await resizeImage(f)); refreshAvatar(); renderMap(); } catch (e) { toast(String(e.message || e)); }
          } }, '📷 ' + t(photoOf(d.id) ? 'Change photo' : 'Add photo')),
          photoOf(d.id) ? h('button', { type: 'button', class: 'ghost danger', onclick: async () => { await removePhoto(d.id); refreshAvatar(); } }, t('Remove photo')) : null)),
        h('div', { class: 'row2' }, field(t('First name'), inp('firstName', { autocomplete: 'off' })), field(t('Last name'), inp('lastName', { autocomplete: 'off' }))),
        field(t('Gender'), segmented(GENDERS.map((g) => [g, GENDER_ICON[g] + ' ' + t(g)]), d.gender, (v) => { d.gender = v; refreshAvatar(); })),
        field(t('Family role'), segmented(ROLES.map((r) => [r, ROLE_ICON[r] + ' ' + t(r)]), d.role, (v) => { d.role = v; })),
        field(t('Birthday'), h('input', { class: 'input', type: 'date', value: d.birthday || '', max: ymdFromDate(new Date()), onchange: (e) => { d.birthday = e.target.value; } })),
        field(t('LINE ID'), inp('lineId', { autocapitalize: 'off', autocorrect: 'off', spellcheck: 'false', placeholder: t('their LINE ID, without ~') }), t('Used for the green LINE button.')),
        h('div', { class: 'row2' }, field(t('Phone'), inp('phone', { type: 'tel', inputmode: 'tel' })), field(t('Email'), inp('email', { type: 'email', inputmode: 'email', autocapitalize: 'off' }))),
        field(t('Notes'), h('textarea', { class: 'input', rows: 3, value: d.notes || '', placeholder: t('has a dog, likes tea…'), oninput: (e) => { d.notes = e.target.value; } })),
        h('button', { class: 'primary wide', type: 'button', onclick: () => {
          d.firstName = d.firstName.trim(); d.lastName = d.lastName.trim();
          if (!d.firstName && !d.lastName) { toast(t('Please enter a name.')); return; }
          d.lineId = cleanLineId(d.lineId); d.phone = d.phone.trim(); d.email = d.email.trim();
          savePerson(houseId, d); m.close(); toast(t('Saved'));
        } }, t('Save')),
        existing ? h('button', { class: 'dangerlink', type: 'button', onclick: async () => {
          if (await confirmDialog({ title: t('Delete {0}?', fullName(d) || t('this person')), ok: t('Delete'), danger: true })) { deletePerson(houseId, d.id); m.close(); toast(t('Deleted.'), { action: { label: t('Undo'), fn: doUndo }, ms: 5000 }); }
        } }, t('Delete resident')) : null);
    },
  });
}

// ----- LINE -----
function openLine(rawId) {
  const clean = cleanLineId(rawId);
  if (!clean) return;
  let left = false;
  const onHide = () => { if (document.visibilityState === 'hidden') left = true; };
  document.addEventListener('visibilitychange', onHide);
  window.location.href = lineAppUrl(clean);
  setTimeout(async () => {
    document.removeEventListener('visibilitychange', onHide);
    if (left) return;
    await copyText(clean);
    toast(t('LINE did not open. The ID "{0}" was copied.', clean), { ms: 7000, action: { label: t('Open in browser'), fn: () => window.open(lineWebUrl(clean), '_blank', 'noopener') } });
  }, 1500);
}
function openLineList(id) {
  openModal({
    title: t('Message on LINE'), back: t('Back'),
    render(body, m) {
      const b = blockById(id);
      if (!b) { m.close(); return; }
      const list = b.residents.filter((p) => p.lineId);
      body.appendChild(h('div', { class: 'linehead' }, h('div', { class: 'linelogo' }, 'LINE'), h('div', null, h('b', null, b.houseName), h('div', { class: 'psub' }, t('{0} LINE contacts', list.length)))));
      if (!list.length) { body.appendChild(h('div', { class: 'empty' }, t('No LINE IDs saved'), h('div', { class: 'psub' }, t('Open Residents and edit a person to add their LINE ID.')))); return; }
      list.forEach((p) => body.appendChild(h('button', { type: 'button', class: 'linecard', onclick: () => openLine(p.lineId) },
        avatar(p, 50), h('div', { class: 'pmain' }, h('div', { class: 'pname' }, fullName(p)), h('div', { class: 'psub' }, t(p.role)), h('div', { class: 'lid' }, p.lineId)), h('span', { class: 'chatbtn' }, '💬 ' + t('Chat')))));
      body.appendChild(h('div', { class: 'fhint center' }, t('If LINE does not open, the ID is copied so you can search for it in LINE.')));
    },
  });
}

// ----- editing a house -----
function openHouseEdit(id) {
  const b = blockById(id);
  if (!b) return;
  const d = { houseName: b.houseName, colorName: b.colorName, icon: b.icon, decoration: b.decoration || '' };
  openModal({
    title: t('Edit House'), live: false, back: t('Back'),
    render(body, m) {
      const photoSlot = h('div', { class: 'avslot' });
      const refreshPhoto = () => {
        const url = photoOf(id);
        photoSlot.replaceChildren(url ? h('img', { class: 'thumb', src: url, alt: '' }) : h('div', { class: 'thumb ph' }, d.decoration || d.icon));
      };
      refreshPhoto();
      const iconRow = h('div', { class: 'iconrow' });
      const drawIcons = () => {
        iconRow.replaceChildren(...HOUSE_ICONS.map((i) => h('button', { type: 'button', class: 'iconpick' + (i === d.icon ? ' sel' : ''), onclick: () => { d.icon = i; drawIcons(); refreshPhoto(); } }, i)),
          HOUSE_ICONS.includes(d.icon) ? null : h('button', { type: 'button', class: 'iconpick sel' }, d.icon),
          h('button', { type: 'button', class: 'iconpick more', onclick: () => openEmojiPicker((em) => { d.icon = em; drawIcons(); refreshPhoto(); }) }, '…'));
      };
      drawIcons();
      const decoSlot = h('div', { class: 'decorow' });
      const drawDeco = () => decoSlot.replaceChildren(
        h('span', { class: 'decoval' }, d.decoration || '–'),
        h('button', { type: 'button', class: 'ghost', onclick: () => openEmojiPicker((em) => { d.decoration = em; drawDeco(); refreshPhoto(); }) }, t('Choose')),
        d.decoration ? h('button', { type: 'button', class: 'ghost', onclick: () => { d.decoration = ''; drawDeco(); refreshPhoto(); } }, t('Clear')) : null);
      drawDeco();
      body.append(
        h('div', { class: 'photorow' }, photoSlot, h('div', { class: 'pbtnrow' },
          h('button', { type: 'button', class: 'ghost', onclick: async () => {
            const f = await pickFile('image/*'); if (!f) return;
            try { await setPhoto(id, await resizeImage(f)); refreshPhoto(); renderMap(); m.update2 && m.update2(); } catch (e) { toast(String(e.message || e)); }
          } }, '📷 ' + t(photoOf(id) ? 'Change house photo' : 'Add house photo')),
          photoOf(id) ? h('button', { type: 'button', class: 'ghost danger', onclick: async () => { await removePhoto(id); refreshPhoto(); renderMap(); } }, t('Remove photo')) : null)),
        field(t('House name'), h('input', { class: 'input', value: d.houseName, oninput: (e) => { d.houseName = e.target.value; } })),
        field(t('Color'), swatchRow(d.colorName, (n) => { d.colorName = n; })),
        field(t('House icon'), iconRow),
        field(t('Decoration emoji (replaces the icon)'), decoSlot),
        h('button', { class: 'primary wide', type: 'button', onclick: () => {
          const name = d.houseName.trim() || b.houseName;
          updateHouse(id, { houseName: name, colorName: d.colorName, icon: d.icon, decoration: d.decoration || null });
          m.close();
        } }, t('Save')));
    },
  });
}

// ----- emoji picker (any emoji at all) -----
const EMOJI_SETS = [
  ['Nature', '🌳🌲🌴🌵🌷🌸🌹🌺🌻🌼🌿🍀🍁🍂🌾🪴🌱🪨⛰️🏔️🌊🏞️🌈'],
  ['Buildings', '🏠🏡🏘️🏢🏬🏪🏫🏥🏦🏣🏤🏛️⛪🕌🛕⛩️🏯🏰🗼🗽🏭🏗️⛲🏮🎡'],
  ['Signs and things', '🪧🚏🚦🚧⚠️🅿️🛑🚸📮📬🔔🏷️🪑🛋️🔑🗑️♻️🚰🧺🪣🧱🪜'],
  ['Vehicles', '🚗🚙🚕🚌🚲🛵🏍️🚚🚛🚜🛻🚑🚒🚓⛽🚉🛤️🛶⛵'],
  ['Animals', '🐕🐈🐦🐇🐢🐟🦆🐿️🐝🦋🐞🐓🐑🐄🦌🐸'],
  ['Food', '🍎🍊🍋🍇🍓🍑🍒🥕🌽🍅🍆🥬🍉🌰🍙🍵'],
  ['Fun', '⚽🎈🎏🎑🪁🎃🏀⚾🎪⛺🔥⭐☀️🌙☃️🎄'],
];
function openEmojiPicker(onPick) {
  openModal({
    title: t('Choose an emoji'), live: false,
    render(body, m) {
      const status = h('div', { class: 'fhint' }, t('Type or paste any emoji. On iPhone use the emoji keyboard, on Mac press Control + Command + Space.'));
      let found = null;
      const useBtn = h('button', { class: 'primary', type: 'button', disabled: true, onclick: () => { if (found) { m.close(); onPick(found); } } }, t('Use this'));
      const prev = h('div', { class: 'emojiprev' }, '·');
      const input = h('input', { class: 'input', placeholder: '🍎', autocomplete: 'off', oninput: (e) => {
        const v = e.target.value.trim();
        found = firstEmoji(v);
        prev.textContent = found || '·';
        useBtn.disabled = !found;
        status.textContent = !v ? t('Type or paste any emoji. On iPhone use the emoji keyboard, on Mac press Control + Command + Space.') : found ? t('Looks good.') : t('That is not an emoji.');
        status.classList.toggle('bad', !!v && !found);
      } });
      body.append(h('div', { class: 'emojirow' }, prev, input, useBtn), status);
      for (const [name, set] of EMOJI_SETS) {
        const list = (typeof Intl !== 'undefined' && Intl.Segmenter) ? [...new Intl.Segmenter(undefined, { granularity: 'grapheme' }).segment(set)].map((x) => x.segment) : Array.from(set);
        body.append(h('div', { class: 'grouphead' }, t(name)), h('div', { class: 'emojigrid' }, list.map((em) => h('button', { type: 'button', class: 'emo', onclick: () => { m.close(); onPick(em); } }, em))));
      }
      setTimeout(() => input.focus({ preventScroll: true }), 50);
    },
  });
}

// ----- sections -----
function openSectionEditor(id) {
  const existing = id ? S.sections.find((s) => s.id === id) : null;
  const d = existing ? { name: existing.name, colorName: existing.colorName } : { name: t('Section {0}', S.sections.length + 1), colorName: nextSectionColor() };
  openModal({
    title: existing ? t('Edit section') : t('New section'), live: false,
    render(body, m) {
      body.append(
        field(t('Section name'), h('input', { class: 'input', value: d.name, placeholder: t('e.g. North side'), oninput: (e) => { d.name = e.target.value; } }), t('Streets in Japan often have no name. A section is any named area you paint on the map.')),
        field(t('Color'), swatchRow(d.colorName, (n) => { d.colorName = n; }, SECTION_COLORS)),
        h('button', { class: 'primary wide', type: 'button', onclick: () => {
          const name = d.name.trim() || t('Section {0}', S.sections.length + 1);
          if (existing) updateSection(existing.id, { name, colorName: d.colorName });
          else { const sec = addSection(name, d.colorName); ui.tool = { type: 'section', sectionId: sec.id }; renderAll(); toast(t('Now tap cells to put them in "{0}".', name)); }
          m.close();
        } }, t('Save')),
        existing ? h('div', { class: 'fhint center' }, t('{0} cells', existing.cells.length)) : null,
        existing ? h('button', { class: 'dangerlink', type: 'button', onclick: async () => {
          if (await confirmDialog({ title: t('Delete section "{0}"?', existing.name), message: t('Only the colored area and its name are removed. Houses are not touched.'), ok: t('Delete'), danger: true })) {
            deleteSection(existing.id); if (ui.tool && ui.tool.sectionId === existing.id) ui.tool.sectionId = null; m.close(); renderAll();
          }
        } }, t('Delete section')) : null);
    },
  });
}

// ----- birthdays -----
function openUpcoming() {
  openModal({
    title: t('Upcoming birthdays'),
    render(body) {
      const list = upcomingBirthdays(120);
      if (!list.length) { body.appendChild(h('div', { class: 'empty' }, h('div', { class: 'big' }, '🎂'), h('div', null, t('No birthdays in the next 120 days.')), h('div', { class: 'psub' }, t('Add a birthday to a resident and it will show here.')))); }
      list.forEach((x) => body.appendChild(h('div', { class: 'prow static' },
        h('div', { class: 'bdate' }, h('div', { class: 'bm' }, fmtMD(x.person.birthday)), h('div', { class: 'bd' }, x.days === 0 ? t('Today') : x.days === 1 ? t('Tomorrow') : t('In {0} days', x.days))),
        h('div', { class: 'pmain' }, h('div', { class: 'pname' }, fullName(x.person) || '?'), h('div', { class: 'psub' }, `${placeLabel(x.block)} · ${t('turns {0}', x.turns)}`)),
        x.person.lineId ? h('button', { type: 'button', class: 'linebtn', onclick: () => openLine(x.person.lineId) }, 'LINE') : null)));
      body.append(h('button', { class: 'primary wide', type: 'button', onclick: exportICS }, '📅 ' + t('Add all birthdays to my Calendar')),
        h('div', { class: 'fhint center' }, t('Downloads a calendar file. Open it on your iPhone or Mac and choose Add All. Every birthday repeats yearly with a reminder.')));
    },
  });
}
function exportICS() {
  const { text, count } = buildBirthdayICS();
  if (!count) { toast(t('No birthdays to export yet.')); return; }
  download('neighbor-birthdays.ics', text, 'text/calendar');
  toast(t('Calendar file with {0} birthdays downloaded.', count));
}

// ----- export / backup -----
function exportCSV() {
  download(`neighborhoodskout-${ymdFromDate(new Date())}.csv`, buildCSV(), 'text/csv;charset=utf-8');
  toast(t('CSV downloaded. Open it in Excel, Numbers or Google Sheets.'));
}
async function buildFullBackup() {
  const photos = {};
  if (!usingFallback) {
    for (const k of await kv.keys()) {
      if (typeof k === 'string' && k.startsWith('photo:')) { const blob = await kv.get(k); if (blob) photos[k.slice(6)] = await blobToDataURL(blob); }
    }
  }
  return JSON.stringify({ app: 'NeighborhoodSkout', format: 'full-backup', version: 2, exportedAt: nowISO(), state: S, photos }, null, 1);
}
async function downloadFullBackup() {
  try {
    const json = await buildFullBackup();
    download(`neighborhoodskout-backup-${ymdFromDate(new Date())}.json`, json, 'application/json');
    settings.lastFileBackup = nowISO(); saveSettings(); refreshModals();
    toast(t('Backup file downloaded. Keep it somewhere safe, like iCloud Drive.'));
  } catch (e) { toast(t('Backup failed: {0}', String(e.message || e))); }
}

// ----- importing -----
async function importFlow() {
  const file = await pickFile('.csv,.json,.txt,text/csv,application/json,text/plain');
  if (!file) return;
  await importBuffer(await file.arrayBuffer(), file.name);
}
async function importBuffer(buf, name) {
  const { text, encoding } = decodeBytes(buf);
  const trimmed = text.replace(/^﻿/, '').trim();
  try {
    if (trimmed.startsWith('{')) {
      const j = JSON.parse(trimmed);
      if (j.format === 'full-backup' && j.state) {
        const st = normalizeState(j.state);
        return showImportPreview({ name, encoding, kind: 'restore', replaceState: st, photos: j.photos || {}, info: t('A complete backup from this app.') });
      }
      if (Array.isArray(j.streets) && Array.isArray(j.blocks)) {
        const st = convertLegacyStore(j);
        return showImportPreview({ name, encoding, kind: 'legacy', replaceState: st, info: t('This is data from the old street-based app. It will be converted to the new grid: every street becomes a section.') });
      }
      if (Array.isArray(j.blocks) && (j.columns || j.sections)) {
        return showImportPreview({ name, encoding, kind: 'restore', replaceState: normalizeState(j), info: t('A map saved by this app.') });
      }
      throw new Error(t('This JSON file is not a NeighborhoodSkout file.'));
    }
    const rows = csvParse(text);
    const kind = detectCSVKind(rows);
    if (kind === 'grid') {
      const merge = planCSVImport(rows, 'merge'), replace = planCSVImport(rows, 'replace');
      return showImportPreview({ name, encoding, kind: 'grid', merge, replace });
    }
    if (kind === 'legacy') {
      const st = convertLegacyStore(parseLegacyCSV(rows));
      return showImportPreview({ name, encoding, kind: 'legacy', replaceState: st, info: t('This is a CSV from the old street-based app. It will be converted to the new grid: every street becomes a section.') });
    }
    throw new Error(t('I could not recognize this file. It needs a header row such as Kind,Section,HouseName,Row,Col…'));
  } catch (e) {
    toast(t('Could not import: {0}', String(e.message || e)), { ms: 7000 });
  }
}
async function applyImported(newState, label, photos) {
  await addBackup(t('Before import'), 'auto').catch(() => {});
  if (photos) for (const [pid, url] of Object.entries(photos)) { try { await setPhoto(pid, await dataURLToBlob(url)); } catch (e) { /* skip one bad photo */ } }
  pushUndo();
  S = normalizeState(newState);
  reindex();
  ui.moving = null; ui.moveSrc = null;
  scheduleSave();
  renderAll();
  toast(label, { action: { label: t('Undo'), fn: doUndo }, ms: 6000 });
}
const countsOf = (st) => ({ houses: st.blocks.filter((b) => b.kind === 'house').length, people: st.blocks.reduce((n, b) => n + b.residents.length, 0), sections: st.sections.length });

function showImportPreview(p) {
  openModal({
    title: t('Import preview'), live: false,
    render(body, m) {
      body.appendChild(h('div', { class: 'fhint' }, `${p.name} · ${t('read as {0}', p.encoding)}`));
      const go = async (st, label) => { m.close(); await applyImported(st, label, p.photos); };
      if (p.kind === 'grid') {
        const pl = p.merge;
        const c = pl.counts;
        const bits = [];
        if (c.newHouses) bits.push(t('{0} new houses', c.newHouses));
        if (c.updatedHouses) bits.push(t('{0} houses updated', c.updatedHouses));
        if (c.newPeople) bits.push(t('{0} new people', c.newPeople));
        if (c.updatedPeople) bits.push(t('{0} people updated', c.updatedPeople));
        if (c.cells) bits.push(t('{0} road/decoration cells', c.cells));
        body.appendChild(h('div', { class: 'sumbox' }, h('div', { class: 'sumline' }, bits.length ? bits.join(' · ') : t('Nothing would change.')),
          h('div', { class: 'psub' }, t('Anything that is not in the file stays as it is.'))));
        const MAX = 150;
        if (pl.changes.length) {
          body.appendChild(h('div', { class: 'grouphead' }, t('Changes')));
          pl.changes.slice(0, MAX).forEach((x) => body.appendChild(h('div', { class: 'chg ' + x.kind }, (x.kind === 'new' ? '＋ ' : '✎ ') + x.text)));
          if (pl.changes.length > MAX) body.appendChild(h('div', { class: 'psub' }, t('…and {0} more.', pl.changes.length - MAX)));
        }
        if (pl.errors.length) {
          body.appendChild(h('div', { class: 'grouphead bad' }, t('Rows I could not read ({0})', pl.errors.length)));
          pl.errors.forEach((x) => body.appendChild(h('div', { class: 'chg err' }, (x.row ? t('Row {0}: ', x.row) : '') + x.msg)));
          body.appendChild(h('div', { class: 'psub' }, t('These rows are skipped. Fix them in the spreadsheet and import again if you need them.')));
        }
        if (pl.warnings.length) {
          body.appendChild(h('div', { class: 'grouphead' }, t('Notes')));
          pl.warnings.forEach((x) => body.appendChild(h('div', { class: 'chg warn' }, x)));
        }
        const rc = countsOf(p.replace.state);
        body.append(
          h('button', { class: 'primary wide', type: 'button', disabled: !bits.length && !pl.changes.length, onclick: () => go(pl.state, t('Imported.')) }, t('Apply these changes')),
          h('div', { class: 'or' }, t('or')),
          h('button', { class: 'dangerbtn wide', type: 'button', onclick: async () => {
            if (await confirmDialog({ title: t('Replace everything?'), message: t('The map becomes exactly what is in the file ({0} houses, {1} people). A backup is made first.', rc.houses, rc.people), ok: t('Replace'), danger: true })) go(p.replace.state, t('Map replaced.'));
          } }, t('Replace everything with this file')));
        return;
      }
      const rc = countsOf(p.replaceState);
      body.append(...[h('div', { class: 'sumbox' }, h('div', { class: 'sumline' }, `${t('{0} houses', rc.houses)} · ${t('{0} people', rc.people)} · ${t('{0} sections', rc.sections)}`), h('div', { class: 'psub' }, p.info)),
        p.photos && Object.keys(p.photos).length ? h('div', { class: 'psub' }, t('{0} photos included.', Object.keys(p.photos).length)) : null,
        h('div', { class: 'psub' }, t('Your current map is backed up first, and you can undo.')),
        h('button', { class: 'primary wide', type: 'button', onclick: async () => {
          if (!S.blocks.length || await confirmDialog({ title: t('Replace everything?'), message: t('Your current map is replaced by this file. A backup is made first.'), ok: t('Replace'), danger: true })) go(p.replaceState, p.kind === 'legacy' ? t('Converted and imported.') : t('Restored.'));
        } }, t('Replace everything with this file'))].filter(Boolean));
    },
  });
}

// ----- settings -----
function openSettings() {
  openModal({
    title: t('Settings'),
    render(body, m) {
      const setS = (k, v) => { settings[k] = v; saveSettings(); if (k === 'lang') { LANG = detectLang(v); } renderAll(); };
      const hourSel = h('select', { class: 'input', onchange: (e) => setS('birthdayHour', +e.target.value) },
        Array.from({ length: 24 }, (_, i) => h('option', { value: i, selected: i === settings.birthdayHour }, `${pad2(i)}:00`)));
      const status = saveStatus.ok
        ? h('div', { class: 'okline' }, '✓ ' + t('Saved on this device') + (saveStatus.at ? ` · ${saveStatus.at.toLocaleTimeString()}` : ''))
        : h('div', { class: 'badline' }, '⚠️ ' + t('Not saved: {0}', saveStatus.error || ''));
      const lastBk = settings.lastFileBackup ? fmtStamp(settings.lastFileBackup) : t('never');
      const bkBox = h('div', { class: 'bklist' }, h('div', { class: 'psub' }, t('Loading…')));
      getBackups().then((list) => {
        bkBox.replaceChildren();
        if (!list.length) bkBox.appendChild(h('div', { class: 'psub' }, t('No backups yet.')));
        list.forEach((bk) => bkBox.appendChild(h('div', { class: 'bkrow' },
          h('div', { class: 'pmain' }, h('div', { class: 'pname' }, `${fmtStamp(bk.at)}`), h('div', { class: 'psub' }, `${bk.label} · ${t('{0} houses', bk.houses)} · ${t('{0} people', bk.people)}`)),
          h('button', { type: 'button', class: 'ghost', onclick: async () => {
            if (!(await confirmDialog({ title: t('Restore this backup?'), message: t('Your current map is backed up first.'), ok: t('Restore') }))) return;
            await addBackup(t('Before restore'), 'auto').catch(() => {});
            pushUndo(); S = normalizeState(JSON.parse(bk.json)); reindex(); scheduleSave(); renderAll(); toast(t('Backup restored.'), { action: { label: t('Undo'), fn: doUndo } });
          } }, t('Restore')),
          h('button', { type: 'button', class: 'ghost danger', 'aria-label': t('Delete'), onclick: async () => { await deleteBackup(bk.id); m.update(); } }, '✕'))));
      });
      body.append(
        h('div', { class: 'sect' }, t('Language')),
        segmented([['auto', t('Auto')], ['en', 'English'], ['ja', '日本語']], settings.lang, (v) => setS('lang', v)),
        h('div', { class: 'sect' }, t('Map')),
        field(t('Grass cells'), segmented([['mint', t('Mint')], ['plain', t('Plain')]], settings.grass, (v) => setS('grass', v)), t('Mint fills empty cells with soft green. Plain shows only a dashed outline.')),
        h('div', { class: 'sect' }, t('Birthdays')),
        field(t('Reminder time (for the calendar file)'), hourSel),
        h('label', { class: 'check' }, h('input', { type: 'checkbox', checked: settings.dayBefore, onchange: (e) => setS('dayBefore', e.target.checked) }), h('span', null, t('Also remind me the day before'))),
        h('button', { class: 'ghost wide', type: 'button', onclick: openUpcoming }, '🎂 ' + t('Upcoming birthdays')),
        h('button', { class: 'ghost wide', type: 'button', onclick: exportICS }, '📅 ' + t('Add all birthdays to my Calendar')),
        ...(sync.enabled ? [
          h('div', { class: 'sect' }, t('Sync')),
          h('div', { class: sync.paused || (!sync.online && sync.error) ? 'badline' : 'okline' }, '☁ ' + syncStatusText()),
          h('div', { class: 'psub' }, t('This device saves to your home server automatically. Every device that opens this address sees the same map.')),
          sync.error && !sync.online ? h('div', { class: 'psub' }, t('Sync problem: {0}', sync.error)) : null,
          h('div', { class: 'btnrow' }, h('button', { class: 'ghost', type: 'button', onclick: () => syncNow({ manual: true }) }, '🔄 ' + t('Sync now'))),
        ].filter(Boolean) : []),
        h('div', { class: 'sect' }, t('Your data')),
        status,
        h('div', { class: 'psub' }, saveStatus.persisted === true ? t('The browser has promised not to clear this data automatically.') : saveStatus.persisted === false ? t('The browser may clear this data if the device runs low on space. Download a backup file now and then.') : ''),
        h('div', { class: 'psub' }, t('Last backup file: {0}', lastBk)),
        h('div', { class: 'btnrow' },
          h('button', { class: 'ghost', type: 'button', onclick: downloadFullBackup }, '⬇️ ' + t('Backup file')),
          h('button', { class: 'ghost', type: 'button', onclick: exportCSV }, '📄 ' + t('Export CSV')),
          h('button', { class: 'ghost', type: 'button', onclick: importFlow }, '⬆️ ' + t('Import…'))),
        h('div', { class: 'btnrow' }, h('button', { class: 'ghost', type: 'button', onclick: async () => { await addBackup(t('Manual backup'), 'manual'); toast(t('Backup saved inside the app.')); m.update(); } }, '💾 ' + t('Back up now (inside the app)'))),
        h('div', { class: 'sect' }, t('Backups inside the app')),
        bkBox,
        h('div', { class: 'sect' }, t('About')),
        h('div', { class: 'psub' }, `NeighborhoodSkout ${APP_VERSION}`),
        h('div', { class: 'psub' }, sync.enabled ? t('Your map is stored on your own home server and on each of your devices. Nothing goes to any company.') : t('Everything stays on this device. There is no account and no server.')),
        h('button', { class: 'dangerlink', type: 'button', onclick: async () => {
          if (!(await confirmDialog({ title: t('Erase the whole map?'), message: t('All houses, people and decorations are removed from the map. A backup is kept inside the app, so you can still restore it.'), ok: t('Erase'), danger: true }))) return;
          await addBackup(t('Before erase'), 'auto').catch(() => {});
          pushUndo(); S = blankState(); reindex(); scheduleSave(); renderAll(); toast(t('Map erased.'), { action: { label: t('Undo'), fn: doUndo } });
        } }, t('Erase the whole map')));
    },
  });
}

function openMenu() {
  openSheet(t('Menu'), '', [
    { label: '🎂 ' + t('Upcoming birthdays'), onClick: openUpcoming },
    { label: '📄 ' + t('Export CSV (for Excel)'), onClick: exportCSV },
    { label: '⬆️ ' + t('Import CSV or backup…'), onClick: importFlow },
    { label: '📅 ' + t('Birthdays to my Calendar'), onClick: exportICS },
    { label: '⬇️ ' + t('Download backup file'), onClick: downloadFullBackup },
  ]);
}
